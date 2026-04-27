# 企业工作资料知识库完全体

这是一个面向企业内部工作资料的 **Full Stack 私有化部署仓库**，目标是搭建一套完整的资料治理与智能问答系统：

```text
Paperless-ngx：企业资料档案柜
RAGFlow：智能检索和问答层
Dify：流程编排层
Caddy：统一入口 / 反向代理
kb-bridge：Paperless → RAGFlow 同步服务
```

本仓库不再包含单容器 Lite / Zeabur 体验版，只保留完全体部署相关内容。

---

## 一、架构定位

这套系统的核心原则是：

```text
先档案化，再智能化。
先治理，再问答。
先确认，再入 RAG。
Paperless 是正式档案源，RAGFlow 是问答副本。
```

组件分工：

| 组件 | 定位 | 主要职责 |
|---|---|---|
| Paperless-ngx | 企业资料档案柜 | 上传、OCR、归档、分类、标签、权限、原件管理 |
| RAGFlow | 智能检索层 | 文档解析、切分、向量索引、问答、引用 |
| Dify | 流程编排层 | 自动分类、审批、字段抽取、调用 API |
| Caddy | 统一入口 | 反向代理、内网域名入口 |
| kb-bridge | 同步服务 | 监听 Paperless outbox，同步可入 RAG 资料到 RAGFlow |

---

## 二、推荐硬件

| 场景 | CPU | 内存 | SSD |
|---|---:|---:|---:|
| 勉强跑通 | 8 核 | 24GB | 200GB |
| 推荐起步 | 12 核 | 32GB | 500GB |
| 舒服使用 | 16 核 | 64GB | 1TB+ |

建议部署在：

```text
PVE VM / VPS / 独立服务器
Ubuntu Server 24.04 / Debian 12
Docker + Docker Compose v2
```

不建议直接公网裸奔，至少使用 VPN、内网 DNS、白名单或认证网关。

---

## 三、快速启动

```bash
git clone https://github.com/jaredshuai/enterprise-kb-zeabur-aio.git
cd enterprise-kb-zeabur-aio

make full-init
vim .env.full
make full-up
make paperless-admin
make full-status
```

第一次启动前，Linux 上建议设置：

```bash
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

详细部署说明见：

```text
docs/FULL_STACK.md
```

---

## 四、资料流

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

## 五、默认端口

```text
Caddy HTTP：8080
Caddy HTTPS：8443
Paperless 直连：18000
Bridge 直连：18080
RAGFlow：默认 80
Dify：默认 8088
```

常用入口：

```text
Paperless: http://服务器IP:18000
Bridge:   http://服务器IP:18080/health
RAGFlow:  http://服务器IP
Dify:     http://服务器IP:8088
```

---

## 六、RAGFlow Dataset 映射

kb-bridge 默认根据 Paperless 的 `document_type` 路由：

| Paperless 文档类型 | RAGFlow Dataset |
|---|---|
| 合同 / 补充协议 | RAGFLOW_CONTRACT_DATASET_ID |
| 招标文件 / 投标文件 | RAGFLOW_BID_DATASET_ID |
| 项目方案 / 技术方案 / 实施方案 | RAGFLOW_PROPOSAL_DATASET_ID |
| 验收报告 / 交付文档 | RAGFLOW_DELIVERY_DATASET_ID |
| 其他 | RAGFLOW_GENERAL_DATASET_ID |

首次启动 RAGFlow 后，需要在页面里创建 Dataset，获取 Dataset ID 和 API Key，然后填入 `.env.full`。

---

## 七、运维命令

```bash
make full-init       # 初始化工作区，拉取 RAGFlow / Dify 官方仓库
make full-up         # 启动完全体
make full-down       # 停止完全体
make full-status     # 查看状态
make full-backup     # 备份 Paperless 与 bridge 关键数据
make paperless-admin # 创建 / 重置 Paperless 管理员
```

---

## 八、安全提醒

1. 真实合同、标书、报价、客户资料涉及商业秘密。
2. 接入外部大模型 / embedding API 前，需要评估公司合规要求。
3. 敏感资料建议只进入 Paperless 归档，不进入通用 RAG。
4. kb-bridge 只负责同步，不替代权限系统。
5. RAGFlow 可重建，Paperless 原件不能丢。
