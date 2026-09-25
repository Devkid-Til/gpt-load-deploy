---
name: gpt-load-setup
description: 用 Claude Code 的 skill 自动完成 gpt-load 自托管 AI 网关的部署：起服务 → 展示登录 key → 问用户要模型/key → 自动建分组挂模型 → 告诉用户怎么接入。
---

# gpt-load 部署 skill

**职责**：把 gpt-load 的部署变成「装完就能用」的自动化流程，不让用户手敲 curl。

## 什么时候触发

用户说「装 gpt-load」「部署 AI 网关」「自建大模型网关」时触发。

## 脚本（本仓库根目录）

skill 直接调用这三个脚本，不用重新实现：

| 脚本 | 干什么 | 用法 |
|---|---|---|
| `setup.sh` | 一键起 docker 服务（含 data 目录属主修正） | `bash scripts/setup.sh [DATA_DIR] [PORT]` |
| `create-group.sh` | 建分组（含 Idempotency-Key、price_multiplier 必填） | `bash scripts/create-group.sh <NAME> <CHANNEL_ID> <BASE_URL>` |
| `add-models.sh` | 挂模型/设别名（先读清单再确认全量替换） | `bash scripts/add-models.sh <GROUP_ID> '<JSON_MODELS>'` |

## 流程

### 1. 起服务

**先问用户**：用 AskUserQuestion 确认——「要在当前机器部署 gpt-load 吗？装到哪个目录？」（默认 `./gpt-load-data`，端口 3001）。用户确认后再调用 `setup.sh`：

```bash
# 如果脚本不在当前目录，先克隆本仓库
if [ ! -f scripts/setup.sh ]; then
  git clone https://github.com/Devkid-Til/gpt-load-deploy-skill.git
  cd gpt-load-deploy-skill
fi
bash scripts/setup.sh
```

`setup.sh` 内部会先弹确认（yes/no），再拉镜像 `ghcr.io/tbphp/gpt-load:2` 并启动容器。跑完后确认 `http://localhost:3001` 能打开。

### 2. 展示登录 key

**管理密钥是 gpt-load 首次启动自动生成的**，位置 `${DATA_DIR}/auth.key`（容器内 `/app/data/auth.key`）。读取并展示给用户：

```bash
docker exec gpt-load cat /app/data/auth.key
```

告诉用户：

> 管理 UI 在 http://localhost:3001，用这把密钥登录。它由 gpt-load 首次启动自动生成、存在 `data/auth.key`——这是唯一的副本，丢了要重置，别提交到任何版本库。想自己指定密钥的话，可以在启动前设 `AUTH_KEY` 环境变量。

顺带提醒：同目录还有 `encryption.key`（用于加密存储上游凭据），同样要保管好。

### 3. 问用户要必要信息

用 AskUserQuestion 逐个问：

1. **要接哪些上游？**（Kimi / DeepSeek / 本地 Ollama / 其他）
2. **每个上游的 API key 是什么？**
3. **模型名和别名是什么？**（比如上游真名 `k3`，想让客户端用 `k3[1m]` 调）

### 4. 自动建分组 + 挂模型

拿到信息后，直接调用 `create-group.sh` 和 `add-models.sh`：

```bash
export GPT_LOAD_AUTH_KEY="<刚才的 AUTH_KEY>"

# 按用户选的上游逐个建分组
bash scripts/create-group.sh kimi-code anthropic https://api.kimi.com/coding
bash scripts/create-group.sh deepseek deepseek https://api.deepseek.com
bash scripts/create-group.sh ollama-local openai_compatible http://<宿主机IP>:11500/v1

# 挂模型（脚本会先读现有清单、确认后再全量替换）
bash scripts/add-models.sh 1 '[{"id":"k3","alias":"k3[1m]","alias_enabled":true}]'
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
- 挂模型前脚本会**先读现有清单并提示确认**，防止全量替换误删
