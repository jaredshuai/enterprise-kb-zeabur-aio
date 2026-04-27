# 企业工作资料知识库 AIO

这个仓库现在包含两种模式：

| 模式 | 定位 | 部署位置 | 适合场景 |
|---|---|---|---|
| **Lite 体验版** | 单容器 AIO，模拟 Paperless/RAGFlow/Dify 的核心体验 | Zeabur / Render / Fly / VPS | 快速体验上传、自动分类、问答、引用 |
| **Full 完全体** | Paperless-ngx + RAGFlow + Dify + Caddy + kb-bridge | PVE / VPS / 独立服务器 | 正式原型、小团队试运行、后续生产化 |

---

## 一、Lite 体验版

Lite 是一个单容器 FastAPI 应用，目标是让你尽快获得这套系统的直观体验：

```text
上传资料 → OCR/文本解析 → 自动分类 → 自动标签 → 切分 Chunk → 向量检索 → 问答 + 引用出处
```

它不是生产级 Paperless-ngx + RAGFlow + Dify 的完整替代，而是把三者的核心体验压缩到一个 Dockerfile 里，方便先部署到 Zeabur 试手感。

### Zeabur 部署

在 Zeabur 中：

```text
Create Project
→ Deploy New Service
→ GitHub
→ 选择 enterprise-kb-zeabur-aio
→ 使用 Dockerfile 构建
```

环境变量：

```env
APP_PASSWORD=换成你的访问密码
APP_SECRET=换成一串随机长字符串
DATA_DIR=/app/data
AUTO_CONFIRM_ON_UPLOAD=true
OCR_LANG=chi_sim+eng
MAX_UPLOAD_MB=50
TOP_K=6
APP_NAME=企业工作资料知识库 AIO
```

挂载 Volume：

```text
/app/data
```

如果不挂载 Volume，服务可以启动，但重新部署后上传文件、SQLite 数据库和索引可能丢失。

### 本地运行 Lite

```bash
cp .env.example .env
make lite-up
```

访问：

```text
http://localhost:8080
```

默认密码：

```text
changeme
```

---

## 二、Full 完全体

Full 模式包含：

```text
Paperless-ngx：企业资料档案柜
RAGFlow：智能检索和问答层
Dify：流程编排层
Caddy：统一入口 / 反向代理
kb-bridge：Paperless → RAGFlow 同步服务
```

完全体不是把所有上游项目手抄进一个巨大 compose，而是采用“统一编排 + 官方栈托管”：

- 本仓库负责 Paperless、Caddy、kb-bridge、初始化脚本、启动脚本、备份脚本。
- RAGFlow 由 `scripts/full-init.sh` 拉取官方仓库，并使用官方 docker compose 启动。
- Dify 由 `scripts/full-init.sh` 拉取官方仓库，并使用官方 docker compose 启动。

这种方式方便后续跟随 RAGFlow / Dify 官方 compose 升级。

### 推荐硬件

| 场景 | CPU | 内存 | SSD |
|---|---:|---:|---:|
| 勉强跑通 | 8 核 | 24GB | 200GB |
| 推荐起步 | 12 核 | 32GB | 500GB |
| 舒服使用 | 16 核 | 64GB | 1TB+ |

### 启动 Full

```bash
git clone https://github.com/jaredshuai/enterprise-kb-zeabur-aio.git
cd enterprise-kb-zeabur-aio

make full-init
vim .env.full
make full-up
make paperless-admin
make full-status
```

详细说明见：

```text
docs/FULL_STACK.md
```

---

## 三、Full 模式资料流

```text
员工上传资料到 Paperless
  ↓
Paperless OCR / 归档 / 分类 / 标签
  ↓
资料管理员确认并加上：状态/可入RAG
  ↓
Paperless post-consume 脚本写入 outbox
  ↓
kb-bridge 扫描 outbox
  ↓
按 document_type 路由到 RAGFlow Dataset
  ↓
RAGFlow 解析、切分、向量化
  ↓
用户做合同条款查询、风险审查、标书分析、历史方案复用
```

---

## 四、可选：接入大模型和 Embedding

Lite 模式可配置 OpenAI-compatible 模型：

```env
LLM_BASE_URL=https://你的模型服务/v1
LLM_API_KEY=你的key
CHAT_MODEL=你的chat模型

EMBEDDING_BASE_URL=https://你的模型服务/v1
EMBEDDING_API_KEY=你的key
EMBEDDING_MODEL=你的embedding模型
```

Full 模式中，RAGFlow 和 Dify 的模型配置建议在各自后台完成；`.env.full` 里预留了模型网关变量，方便后续脚本化。

---

## 五、适合测试的问题

先上传 `samples/` 里的示例文件，然后问：

```text
这个合同的付款方式是什么？
质保期多久？
有哪些违约责任？
招标文件有哪些关键要求？
验收条件是什么？
项目周期是多少？
```

---

## 六、重要说明

1. Lite 适合公网平台快速体验；Full 适合 PVE / VPS / 独立服务器。
2. Full 不建议直接暴露公网，至少使用 VPN、内网 DNS、白名单或认证网关。
3. Paperless 是正式档案源；RAGFlow 是问答副本。RAGFlow 可以重建，Paperless 原件不能丢。
4. 真实合同、标书、报价、客户资料涉及商业秘密，接外部模型前要评估合规风险。
5. kb-bridge 只负责同步，不替代权限系统。敏感资料应只归档，不进通用 RAG。
