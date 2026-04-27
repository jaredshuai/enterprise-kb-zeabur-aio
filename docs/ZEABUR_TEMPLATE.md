# Zeabur Template 部署说明

本仓库提供了一个实验性的 Zeabur Template：

```text
zeabur-template.yaml
```

目标是尽量把完全体栈拆成 Zeabur 可理解的多服务资源：

```text
Paperless-ngx
Paperless PostgreSQL
Paperless Redis
Gotenberg
Tika
RAGFlow
RAGFlow MySQL
RAGFlow Redis / Valkey
RAGFlow MinIO
RAGFlow Elasticsearch
Dify API
Dify Web
Dify PostgreSQL
Dify Redis
Dify Weaviate
kb-bridge
```

---

## 一、重要说明

Zeabur Template 路线和 PVE/VPS Full 路线不同。

PVE/VPS Full 路线：

```text
make full-init
make full-up
```

它会拉取 RAGFlow / Dify 官方仓库，并运行官方 Docker Compose。

Zeabur Template 路线：

```text
Zeabur Template
  ↓
Zeabur 创建多个独立服务
  ↓
每个服务单独运行镜像、环境变量、端口和 Volume
```

由于 Zeabur 目前不是直接运行 Docker Compose YAML，而是需要 Template YAML，所以模板里的服务是“手工拆分版”。这比 PVE/VPS 路线更容易遇到上游镜像变量、端口、依赖变化的问题。

---

## 二、部署入口

在 Zeabur 里：

```text
添加服务
→ 模板
→ 使用自定义模板 / 导入模板 YAML
→ 选择本仓库的 zeabur-template.yaml
```

如果 Zeabur UI 不支持直接从仓库读取该模板，可以把 `zeabur-template.yaml` 内容复制进去。

---

## 三、模板中的服务

### Paperless 组

```text
paperless
paperless-postgres
paperless-redis
paperless-gotenberg
paperless-tika
```

用途：

```text
资料上传
OCR
Office 文档解析
PDF/A 归档
标签 / 文档类型 / 客户 / 项目
```

### RAGFlow 组

```text
ragflow
ragflow-mysql
ragflow-redis
ragflow-minio
ragflow-elasticsearch
```

用途：

```text
文档解析
切分
向量化
检索
问答
引用出处
```

### Dify 组

```text
dify-api
dify-web
dify-postgres
dify-redis
dify-weaviate
```

用途：

```text
工作流
应用编排
自动分类
字段抽取
后续业务流程
```

### Bridge

```text
kb-bridge
```

用途：

```text
监听 Paperless outbox
读取文档 metadata
根据 document_type 路由到 RAGFlow Dataset
调用 RAGFlow API 上传并触发解析
```

---

## 四、变量说明

模板会要求填写这些变量：

```text
PAPERLESS_SECRET_KEY
PAPERLESS_POSTGRES_PASSWORD
BRIDGE_API_KEY
RAGFLOW_API_KEY
RAGFLOW_CONTRACT_DATASET_ID
RAGFLOW_BID_DATASET_ID
RAGFLOW_PROPOSAL_DATASET_ID
RAGFLOW_DELIVERY_DATASET_ID
RAGFLOW_GENERAL_DATASET_ID
```

其中 RAGFlow 相关变量可以先留空。等 RAGFlow 启动后：

```text
1. 登录 RAGFlow
2. 创建 Dataset：合同库、招投标库、项目方案库、验收交付库、综合资料库
3. 获取 Dataset ID
4. 获取 RAGFlow API Key
5. 回填到 Zeabur 服务变量
6. 重启 kb-bridge
```

---

## 五、部署后优先检查

按顺序打开：

```text
paperless 服务域名
ragflow 服务域名
dify-web 服务域名
kb-bridge /health
```

如果某个服务失败，优先看它的日志。

常见问题：

```text
1. RAGFlow 起不来：通常是依赖服务未就绪、ES 内存不足、镜像环境变量与当前上游版本不匹配。
2. Dify 起不来：通常是 API/Web 的环境变量不完整，或 Dify 当前版本新增了必需服务。
3. Paperless 无法连接数据库：检查 paperless-postgres 服务名、密码变量。
4. kb-bridge 无法同步：检查 RAGFLOW_API_KEY、Dataset ID、RAGFlow 地址。
```

---

## 六、现实建议

Zeabur Template 可以用来“全量尝试”，但完全体最稳的路线仍然是 PVE/VPS：

```text
PVE/VPS：稳定性、可控性、备份、端口、资源都更适合完全体。
Zeabur Template：适合快速试验和验证多服务可行性。
```

如果 Zeabur Template 中 RAGFlow 或 Dify 失败，建议：

```text
Paperless + kb-bridge 保留在 Zeabur
RAGFlow / Dify 使用 Zeabur 官方模板或部署到 VPS/PVE
```

---

## 七、后续可优化

```text
1. 为 kb-bridge 提供独立镜像，避免运行时 pip install。
2. 把 Dify 服务补齐到官方 compose 等价结构。
3. 把 RAGFlow 依赖变量和当前官方 compose 对齐。
4. 增加 Zeabur 内部服务健康检查。
5. 为 Paperless outbox 和 kb-bridge 建立共享对象存储或 API 同步方式。
```
