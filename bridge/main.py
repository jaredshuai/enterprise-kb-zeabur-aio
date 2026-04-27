import asyncio
import json
import os
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

import httpx
from fastapi import FastAPI, Header, HTTPException

DATA_DIR = Path(os.getenv("DATA_DIR", "/data"))
OUTBOX_DIR = Path(os.getenv("OUTBOX_DIR", "/paperless-outbox"))
PENDING_DIR = OUTBOX_DIR / "pending"
DONE_DIR = OUTBOX_DIR / "done"
FAILED_DIR = OUTBOX_DIR / "failed"

BRIDGE_API_KEY = os.getenv("BRIDGE_API_KEY", "change-me-bridge-key")
SYNC_ENABLED = os.getenv("BRIDGE_SYNC_ENABLED", "true").lower() == "true"
REQUIRE_TAG = os.getenv("BRIDGE_REQUIRE_TAG", "状态/可入RAG")
SUCCESS_TAG = os.getenv("BRIDGE_SUCCESS_TAG", "状态/已入RAG")
FAILED_TAG = os.getenv("BRIDGE_FAILED_TAG", "状态/同步失败")
POLL_SECONDS = int(os.getenv("BRIDGE_POLL_SECONDS", "120"))

RAGFLOW_BASE_URL = os.getenv("RAGFLOW_BASE_URL", "").rstrip("/")
RAGFLOW_API_KEY = os.getenv("RAGFLOW_API_KEY", "")
DATASET_MAP = {
    "合同": os.getenv("RAGFLOW_CONTRACT_DATASET_ID", ""),
    "补充协议": os.getenv("RAGFLOW_CONTRACT_DATASET_ID", ""),
    "招标文件": os.getenv("RAGFLOW_BID_DATASET_ID", ""),
    "投标文件": os.getenv("RAGFLOW_BID_DATASET_ID", ""),
    "项目方案": os.getenv("RAGFLOW_PROPOSAL_DATASET_ID", ""),
    "技术方案": os.getenv("RAGFLOW_PROPOSAL_DATASET_ID", ""),
    "实施方案": os.getenv("RAGFLOW_PROPOSAL_DATASET_ID", ""),
    "验收报告": os.getenv("RAGFLOW_DELIVERY_DATASET_ID", ""),
    "交付文档": os.getenv("RAGFLOW_DELIVERY_DATASET_ID", ""),
    "default": os.getenv("RAGFLOW_GENERAL_DATASET_ID", ""),
}

app = FastAPI(title="Enterprise KB Bridge")


def now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def ensure_dirs() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    for p in (PENDING_DIR, DONE_DIR, FAILED_DIR):
        p.mkdir(parents=True, exist_ok=True)


def log_event(event: Dict[str, Any]) -> None:
    ensure_dirs()
    event = {"time": now(), **event}
    with (DATA_DIR / "bridge-events.jsonl").open("a", encoding="utf-8") as f:
        f.write(json.dumps(event, ensure_ascii=False) + "\n")


def require_auth(x_bridge_key: Optional[str]) -> None:
    if x_bridge_key != BRIDGE_API_KEY:
        raise HTTPException(status_code=401, detail="invalid bridge key")


def parse_tags(value: str) -> list[str]:
    if not value:
        return []
    if value.strip().startswith("["):
        try:
            data = json.loads(value)
            return [str(x) for x in data]
        except Exception:
            pass
    return [x.strip() for x in value.replace(";", ",").replace("|", ",").split(",") if x.strip()]


def should_sync(meta: Dict[str, Any]) -> bool:
    if not REQUIRE_TAG:
        return True
    tags = parse_tags(str(meta.get("tags", "")))
    return REQUIRE_TAG in tags


def choose_dataset(meta: Dict[str, Any]) -> str:
    doc_type = str(meta.get("document_type") or "").strip()
    return DATASET_MAP.get(doc_type) or DATASET_MAP.get("default") or ""


def resolve_file(meta: Dict[str, Any], meta_path: Path) -> Optional[Path]:
    source = str(meta.get("source_file") or "")
    if source:
        # Paperless wrote container path. In this container both map to OUTBOX_DIR.
        source = source.replace("/usr/src/paperless/outbox", str(OUTBOX_DIR))
        p = Path(source)
        if p.exists():
            return p
    candidates = [p for p in meta_path.parent.glob(f"{meta.get('paperless_id', '')}-*") if p.is_file()]
    return candidates[0] if candidates else None


async def upload_to_ragflow(dataset_id: str, file_path: Path) -> Dict[str, Any]:
    if not RAGFLOW_BASE_URL or not RAGFLOW_API_KEY:
        raise RuntimeError("RAGFLOW_BASE_URL or RAGFLOW_API_KEY is not configured")
    async with httpx.AsyncClient(timeout=180) as client:
        with file_path.open("rb") as f:
            resp = await client.post(
                f"{RAGFLOW_BASE_URL}/api/v1/datasets/{dataset_id}/documents",
                headers={"Authorization": f"Bearer {RAGFLOW_API_KEY}"},
                files={"file": (file_path.name, f, "application/octet-stream")},
            )
        resp.raise_for_status()
        data = resp.json()
        code = data.get("code")
        if code not in (0, "0", None):
            raise RuntimeError(f"RAGFlow upload failed: {data}")
        doc_ids = [x.get("id") for x in data.get("data", []) if x.get("id")]
        if doc_ids:
            parse_resp = await client.post(
                f"{RAGFLOW_BASE_URL}/api/v1/datasets/{dataset_id}/chunks",
                headers={"Authorization": f"Bearer {RAGFLOW_API_KEY}", "Content-Type": "application/json"},
                json={"document_ids": doc_ids},
            )
            parse_resp.raise_for_status()
            return {"upload": data, "parse": parse_resp.json(), "document_ids": doc_ids}
        return {"upload": data, "parse": None, "document_ids": []}


def move_pair(meta_path: Path, file_path: Optional[Path], target_root: Path, status: str, result: Dict[str, Any] | None = None) -> None:
    target_dir = target_root / meta_path.stem
    target_dir.mkdir(parents=True, exist_ok=True)
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    meta["status"] = status
    meta["bridge_time"] = now()
    if result is not None:
        meta["bridge_result"] = result
    (target_dir / meta_path.name).write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    if file_path and file_path.exists():
        shutil.move(str(file_path), str(target_dir / file_path.name))
    meta_path.unlink(missing_ok=True)


async def process_one(meta_path: Path) -> Dict[str, Any]:
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    file_path = resolve_file(meta, meta_path)
    if not file_path or not file_path.exists():
        raise RuntimeError("source file not found")
    if not should_sync(meta):
        return {"skipped": True, "reason": f"missing required tag: {REQUIRE_TAG}"}
    dataset_id = choose_dataset(meta)
    if not dataset_id:
        raise RuntimeError(f"dataset id not configured for document_type={meta.get('document_type')}")
    result = await upload_to_ragflow(dataset_id, file_path)
    move_pair(meta_path, file_path, DONE_DIR, "synced", result)
    return {"synced": True, "dataset_id": dataset_id, "file": file_path.name}


async def scan_once() -> Dict[str, Any]:
    ensure_dirs()
    metas = sorted(PENDING_DIR.glob("*.json"))
    stats = {"scanned": len(metas), "synced": 0, "skipped": 0, "failed": 0}
    for meta_path in metas:
        try:
            result = await process_one(meta_path)
            if result.get("skipped"):
                stats["skipped"] += 1
            else:
                stats["synced"] += 1
            log_event({"event": "processed", "meta": meta_path.name, "result": result})
        except Exception as exc:
            stats["failed"] += 1
            try:
                meta = json.loads(meta_path.read_text(encoding="utf-8"))
                file_path = resolve_file(meta, meta_path)
                move_pair(meta_path, file_path, FAILED_DIR, "failed", {"error": str(exc), "failed_tag": FAILED_TAG})
            except Exception:
                pass
            log_event({"event": "failed", "meta": meta_path.name, "error": str(exc)})
    return stats


async def background_loop() -> None:
    await asyncio.sleep(10)
    while True:
        if SYNC_ENABLED:
            try:
                await scan_once()
            except Exception as exc:
                log_event({"event": "loop_error", "error": str(exc)})
        await asyncio.sleep(POLL_SECONDS)


@app.on_event("startup")
async def startup() -> None:
    ensure_dirs()
    asyncio.create_task(background_loop())


@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "ok": True,
        "time": now(),
        "sync_enabled": SYNC_ENABLED,
        "pending": len(list(PENDING_DIR.glob("*.json"))) if PENDING_DIR.exists() else 0,
        "ragflow_configured": bool(RAGFLOW_BASE_URL and RAGFLOW_API_KEY),
    }


@app.post("/scan")
async def manual_scan(x_bridge_key: Optional[str] = Header(default=None)) -> Dict[str, Any]:
    require_auth(x_bridge_key)
    return await scan_once()


@app.get("/events")
def events(x_bridge_key: Optional[str] = Header(default=None), limit: int = 100) -> Dict[str, Any]:
    require_auth(x_bridge_key)
    path = DATA_DIR / "bridge-events.jsonl"
    if not path.exists():
        return {"events": []}
    lines = path.read_text(encoding="utf-8").splitlines()[-limit:]
    return {"events": [json.loads(x) for x in lines if x.strip()]}
