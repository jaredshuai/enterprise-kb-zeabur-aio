# 企业工作资料知识库完全体部署说明

本仓库现在包含两种模式：

| 模式 | 说明 | 适合场景 |
|---|---|---|
| Lite | 单容器 FastAPI AIO 体验版 | Zeabur / 快速体验 |
| Full | Paperless-ngx + RAGFlow + Dify + Caddy + kb-bridge | PVE / VPS / 独立服务器 |

完全体不是把所有上游项目手抄进一个巨型 compose，而是采用“统一编排 + 官方栈托管”的方式：

- 本仓库负责：Paperless 编排、Caddy、kb-bridge、初始化脚本、启动脚本、备份脚本、文档。
- RAGFlow：由 `scripts/full-init.sh` 拉取官方仓库，并使用官方 docker compose 启动。
- Dify：由 `scripts/full-init.sh` 拉取官方仓库，并使用官方 docker compose 启动。

这样做的好处是：RAGFlow / Dify 后续升级时可以跟随官方 compose，避免本仓库维护一份过时的大型配置。

---

## 一、推荐硬件

最低能跑：

```text
CPU：8 核
内存：24GB
SSD：200GB
```

推荐起步：

```text
CPU：12 核
内存：32GB
SSD：500GB
```

舒服使用：

```text
CPU：16 核
内存：64GB
SSD：1TB+
```

GPU 不是必须。当前方案默认依赖外部大模型 / embedding API，或者由 RAGFlow/Dify 自己配置模型。

---

## 二、组件分工

```text
Paperless-ngx：资料档案柜，负责上传、OCR、归档、文档类型、客户/项目、标签、权限。
RAGFlow：智能检索和问答层，负责文档解析、切分、向量索引、问答、引用。
Dify：流程编排层，负责后续自动分类、审批、字段抽取、业务流程。
Caddy：统一入口和反向代理。
kb-bridge：监听 Paperless outbox，把“状态/可入RAG”的资料同步到 RAGFlow Dataset。
```

---

## 三、快速启动

### 1. 克隆仓库

```bash
git clone https://github.com/jaredshuai/enterprise-kb-zeabur-aio.git
cd enterprise-kb-zeabur-aio
```

### 2. 初始化完全体工作区

```bash
make full-init
```

该步骤会：

```text
生成 .env.full
创建 runtime 目录
创建 Paperless consume/media/outbox 目录
拉取 RAGFlow 官方仓库到 runtime/vendor/ragflow
拉取 Dify 官方仓库到 runtime/vendor/dify
复制 Dify docker/.env.example 为 docker/.env
尝试将 Dify 默认 Nginx 端口改成 8088，避免和 RAGFlow 的 80 端口冲突
```

### 3. 修改配置

编辑：

```bash
vim .env.full
```

至少修改：

```env
PAPERLESS_ADMIN_PASSWORD=你的密码
PAPERLESS_SECRET_KEY=随机长字符串
PAPERLESS_POSTGRES_PASSWORD=随机数据库密码
BRIDGE_API_KEY=随机长字符串
```

如果使用内网域名，需要在你的 DNS 或本机 hosts 中配置：

```text
paperless.kb.local
ragflow.kb.local
dify.kb.local
bridge.kb.local
```

默认端口：

```text
Caddy HTTP：8080
Caddy HTTPS：8443
Paperless 直连：18000
Bridge 直连：18080
RAGFlow 官方栈：80
Dify 官方栈：8088
```

### 4. 设置 vm.max_map_count

RAGFlow 使用 Elasticsearch 或 Infinity 作为召回组件时需要较高的 `vm.max_map_count`。Linux 上建议执行：

```bash
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 5. 启动完全体

```bash
make full-up
```

### 6. 创建 Paperless 管理员

```bash
make paperless-admin
```

### 7. 查看状态

```bash
make full-status
```

---

## 四、访问入口

默认：

```text
Paperless: http://paperless.kb.local:8080
RAGFlow:  http://ragflow.kb.local:8080
Dify:     http://dify.kb.local:8080
Bridge:   http://bridge.kb.local:8080
```

也可以直连：

```text
Paperless: http://服务器IP:18000
Bridge:   http://服务器IP:18080/health
RAGFlow:  http://服务器IP
Dify:     http://服务器IP:8088
```

---

## 五、推荐资料流

```text
1. 员工把文件上传到 Paperless，或放入 runtime/paperless/consume。
2. Paperless 进行 OCR、归档、自动分类、标签。
3. 资料管理员确认资料，并加上标签：状态/可入RAG。
4. Paperless post-consume 脚本把文件和 metadata 写到 outbox。
5. kb-bridge 扫描 outbox/pending。
6. kb-bridge 根据 document_type 路由到对应 RAGFlow Dataset。
7. RAGFlow 完成解析、切分、向量化。
8. 用户在 RAGFlow / Dify 中进行问答、审查、对比。
```

---

## 六、RAGFlow Dataset 映射

kb-bridge 默认根据 `document_type` 路由：

| Paperless 文档类型 | RAGFlow Dataset |
|---|---|
| 合同 / 补充协议 | RAGFLOW_CONTRACT_DATASET_ID |
| 招标文件 / 投标文件 | RAGFLOW_BID_DATASET_ID |
| 项目方案 / 技术方案 / 实施方案 | RAGFLOW_PROPOSAL_DATASET_ID |
| 验收报告 / 交付文档 | RAGFLOW_DELIVERY_DATASET_ID |
| 其他 | RAGFLOW_GENERAL_DATASET_ID |

使用步骤：

1. 在 RAGFlow Web 页面中创建 Dataset。
2. 获取 Dataset ID。
3. 在 `.env.full` 中填写对应变量。
4. 获取 RAGFlow API Key，填写 `RAGFLOW_API_KEY`。
5. 重启 bridge：

```bash
docker compose --env-file .env.full -f full/compose.paperless.yml -f full/compose.platform.yml restart kb-bridge
```

手动触发扫描：

```bash
curl -X POST \
  -H "X-Bridge-Key: 你的BRIDGE_API_KEY" \
  http://localhost:18080/scan
```

---

## 七、备份

执行：

```bash
make full-backup
```

当前脚本会备份：

```text
.env.full 副本
Paperless PostgreSQL dump
Paperless 文件目录，不含 postgres/redis 运行目录
Bridge 状态和日志
```

RAGFlow / Dify 使用官方 compose 和 volume，正式生产建议同时做：

```text
PVE VM 级快照
整机数据盘快照
RAGFlow 官方迁移/备份流程
Dify 官方备份流程
```

---

## 八、停止服务

```bash
make full-down
```

---

## 九、注意事项

1. 这套完全体适合 PVE / VPS / 独立服务器，不适合普通 Zeabur 共享容器。
2. RAGFlow 与 Dify 都是大型多容器系统，首次拉取镜像需要较长时间。
3. 不要把真实敏感合同直接暴露到公网。
4. 如果要公网访问，建议使用 VPN、白名单、反向代理鉴权或单独认证网关。
5. kb-bridge 只负责 Paperless → RAGFlow 的同步，不替代权限系统。
6. Paperless 是正式档案源，RAGFlow 是问答副本。RAGFlow 可重建，Paperless 原件不能丢。
