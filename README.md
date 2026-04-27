# 企业工作资料知识库 AIO（Zeabur 体验版）

这是一个 **单容器 All-in-One 企业资料知识库体验版**，目标是让你尽快获得这套系统的直观体验：

```text
上传资料 → OCR/文本解析 → 自动分类 → 自动标签 → 切分 Chunk → 向量检索 → 问答 + 引用出处
```

它不是生产级 Paperless-ngx + RAGFlow + Dify 的完整替代，而是把三者的核心体验压缩到一个 Dockerfile 里，方便先部署到 Zeabur 试手感。

- Paperless-like：上传、OCR、原件保存、文档类型、客户/项目、标签、状态。
- RAGFlow-like：切分、向量检索、问答、引用来源。
- Dify-like：自动分类、状态流转、确认入库。

## 一、最快部署到 Zeabur

### 1. 推送到 GitHub

```bash
git init
git add .
git commit -m "init enterprise kb aio"
git branch -M main
git remote add origin https://github.com/<你的用户名>/enterprise-kb-zeabur-aio.git
git push -u origin main
```

或者使用脚本：

```bash
bash scripts/create-github-repo-and-push.sh enterprise-kb-zeabur-aio
```

> 脚本需要你本机已安装 `gh` 并已登录。如果没有 `gh`，就在 GitHub 网页新建空仓库，再按上面的 git 命令 push。

### 2. Zeabur 导入 GitHub 仓库

在 Zeabur 中：

```text
Create Project
→ Deploy New Service
→ GitHub
→ 选择 enterprise-kb-zeabur-aio
→ 使用 Dockerfile 构建
```

本项目根目录已经包含 `Dockerfile`，Zeabur 会按 Dockerfile 构建镜像。

### 3. 配置环境变量

至少配置：

```env
APP_PASSWORD=换成你的访问密码
APP_SECRET=换成一串随机长字符串
DATA_DIR=/app/data
AUTO_CONFIRM_ON_UPLOAD=true
OCR_LANG=chi_sim+eng
MAX_UPLOAD_MB=50
TOP_K=6
```

推荐再配置：

```env
APP_NAME=企业工作资料知识库 AIO
```

如果不配置大模型，也能使用本地规则分类、本地哈希向量检索和抽取式引用回答。

### 4. 挂载持久化 Volume

为了让上传资料、SQLite 数据库和索引不丢，需要把 Volume 挂载到：

```text
/app/data
```

如果不挂载 Volume，服务可以启动，但重新部署后数据可能丢失。

### 5. 打开公网域名

在 Zeabur 服务里绑定或生成公网域名，然后访问即可。

登录密码就是你设置的：

```env
APP_PASSWORD
```

## 二、可选：接入大模型和 Embedding

如果你有 OpenAI-compatible 模型服务，例如 NewAPI、豆包、DeepSeek 网关等，可以配置：

```env
LLM_BASE_URL=https://你的模型服务/v1
LLM_API_KEY=你的key
CHAT_MODEL=你的chat模型

EMBEDDING_BASE_URL=https://你的模型服务/v1
EMBEDDING_API_KEY=你的key
EMBEDDING_MODEL=你的embedding模型
```

配置后：

- 自动分类会优先用 LLM 输出结构化 metadata。
- 问答会优先用 LLM 基于召回片段生成回答。
- 向量化会优先调用远程 embedding。

不配置时：

- 自动分类：本地关键词规则。
- 检索：本地哈希向量。
- 回答：抽取式相关片段展示。

## 三、本地运行

```bash
cp .env.example .env
make up
```

访问：

```text
http://localhost:8080
```

默认密码：

```text
changeme
```

## 四、适合测试的问题

先上传 `samples/` 里的示例文件，然后问：

```text
这个合同的付款方式是什么？
质保期多久？
有哪些违约责任？
招标文件有哪些关键要求？
验收条件是什么？
项目周期是多少？
```

## 五、支持格式

```text
PDF、DOCX、TXT、MD、PNG、JPG、JPEG、WEBP、BMP、TIFF
```

当前体验版暂不内置 Excel / PPT 解析。正式版建议迁移到 Paperless-ngx + Tika/Gotenberg 或 RAGFlow。

## 六、重要说明

1. 公网访问时必须设置 `APP_PASSWORD`。
2. 不要在未评估合规前上传真实敏感合同、客户资料或个人信息。
3. 这是体验版，数据存储使用 SQLite + 本地文件。正式部署建议迁移到 PVE 上的 Paperless-ngx + RAGFlow。
4. 如果接豆包 embedding，只要你的服务兼容 `/v1/embeddings`，可填入 `EMBEDDING_*` 变量。

## 七、后续迁移路线

```text
Zeabur AIO 体验版
  ↓
Paperless-ngx 作为正式档案柜
  ↓
RAGFlow 作为正式问答和审查层
  ↓
Dify 编排自动分类与审批
  ↓
doubao-embedding-vision 做图文检索增强
```
