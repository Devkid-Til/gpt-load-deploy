---
name: gpt-load-setup
description: 用 Claude Code 的 skill 自动完成 gpt-load 自托管 AI 网关的部署：起服务 → 展示登录 key → 问用户要模型/key → 自动建分组挂模型 → 告诉用户怎么接入。
---

# gpt-load 部署 skill

**职责**：把 gpt-load 的部署变成「装完就能用」的自动化流程，不让用户手敲 curl。

## 什么时候触发

用户说「装 gpt-load」「部署 AI 网关」「自建大模型网关」时触发。

## 流程

### 1. 起服务

```bash
# 如果 setup.sh 在当前目录，直接跑；否则先克隆仓库
if [ ! -f setup.sh ]; then
  git clone https://github.com/Devkid-Til/gpt-load-deploy.git
  cd gpt-load-deploy
fi
bash setup.sh
```

跑完后确认 `http://localhost:3001` 能打开，从日志或 credentials.txt 里拿到 AUTH_KEY。

### 2. 展示登录 key

把 AUTH_KEY 展示给用户，告诉用户：

> 管理 UI 在 http://localhost:3001，用这个 key 登录。key 已存到 credentials.txt（权限 600），别提交到任何版本库。

### 3. 问用户要必要信息

用 AskUserQuestion 逐个问：

1. **要接哪些上游？**（Kimi / DeepSeek / 本地 Ollama / 其他）
2. **每个上游的 API key 是什么？**
3. **模型名和别名是什么？**（比如上游真名 `k3`，想让客户端用 `k3[1m]` 调）

### 4. 自动建分组 + 挂模型

拿到信息后，跑 create-group.sh 和 add-models.sh：

```bash
export GPT_LOAD_AUTH_KEY="<刚才的 AUTH_KEY>"

# 按用户选的上游逐个建分组
bash create-group.sh kimi-code anthropic https://api.kimi.com/coding
bash create-group.sh deepseek deepseek https://api.deepseek.com
bash create-group.sh ollama-local openai_compatible http://<宿主机IP>:11500/v1

# 挂模型（注意全量替换，漏写的会被删）
bash add-models.sh 1 '[{"id":"k3","alias":"k3[1m]","alias_enabled":true}]'
```

### 5. 告诉用户怎么接入

配好后告诉用户：

```bash
export ANTHROPIC_BASE_URL=http://localhost:3001
export ANTHROPIC_API_KEY=<刚发的 AccessKey>
```

Dify 容器内用宿主机 IP（`host.docker.internal` 在容器里不解析）。

## 注意

- **密钥不写进任何版本库**，AUTH_KEY 和 AccessKey 都只展示一次、存 credentials.txt
- 建分组前确认脚本已可执行（`chmod +x *.sh`）
- 挂模型前**必须先读现有清单**（add-models.sh 会提示确认），防止全量替换误删
