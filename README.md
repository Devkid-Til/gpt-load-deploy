# gpt-load-deploy-skill

> Claude Code skill：一条命令部署 [gpt-load](https://github.com/tbphp/gpt-load) 自托管 AI 网关

把 gpt-load 的部署变成「回答问题就能用」——装服务、建分组、挂模型、发 AccessKey，全程不用手敲 curl。

gpt-load 是 Go 单二进制 + SQLite 的轻量 AI 网关：多渠道多凭据统一接入，含密钥与订阅账号、调度容错、日志与用量。

## 两种用法

### 方式一：用 Claude Code skill（推荐）

把本仓库放进 Claude Code 的 skills 目录：

```bash
git clone https://github.com/Devkid-Til/gpt-load-deploy-skill.git
ln -s "$PWD/gpt-load-deploy-skill" ~/.claude/skills/gpt-load-setup
```

然后在 Claude Code 里说「装 gpt-load」。skill 会：

1. 问你部署到哪个目录，确认后起容器
2. 展示管理 UI 的登录 key
3. 问你要接哪些上游、API key 是什么、模型名和别名
4. 自动建分组、挂模型
5. 告诉你客户端怎么接入

### 方式二：手动跑脚本

```bash
git clone https://github.com/Devkid-Til/gpt-load-deploy-skill.git
cd gpt-load-deploy-skill
chmod +x scripts/*.sh
```

**1. 起服务**

```bash
bash scripts/setup.sh                    # 默认 ./gpt-load-data + 3001 端口
bash scripts/setup.sh /path/to/data 3001 # 自定义
```

跑完管理 UI 在 `http://localhost:3001`，用 `credentials.txt` 里的 AUTH_KEY 登录。

**2. 建分组**

```bash
export GPT_LOAD_AUTH_KEY="<你的 AUTH_KEY>"

bash scripts/create-group.sh kimi-code anthropic https://api.kimi.com/coding
bash scripts/create-group.sh deepseek deepseek https://api.deepseek.com
bash scripts/create-group.sh ollama-local openai_compatible http://<宿主机IP>:11500/v1
```

**3. 挂模型 + 设别名**

```bash
# 全量替换，脚本会先读现有清单再确认，防误删
bash scripts/add-models.sh <GROUP_ID> '[{"id":"k3","alias":"k3[1m]","alias_enabled":true}]'
```

**4. 验证**

```bash
curl -s -H "Authorization: Bearer $GPT_LOAD_AUTH_KEY" http://localhost:3001/api/groups
# 每个分组的 service_status 应为 available
```

## 客户端接入

```bash
export ANTHROPIC_BASE_URL=http://localhost:3001
export ANTHROPIC_API_KEY=sk-gl-<你的>-<hex>
```

Dify 容器内用宿主机 IP（`host.docker.internal` 在容器里不解析）。

## 目录结构

```
SKILL.md                  skill 定义（Claude Code 读这个）
scripts/setup.sh          起 docker 服务
scripts/create-group.sh   建分组
scripts/add-models.sh     挂模型 / 设别名
references/               预留：排障记录、架构说明
```

## 踩过的坑（都验证过）

| # | 坑 | 后果 |
|---|---|---|
| 1 | data 目录属主不是容器 uid 10001 | bind mount 宿主目录（uid 1000）直接 EPERM 崩溃循环 |
| 2 | 建分组不带 `Idempotency-Key` 头 | 428 |
| 3 | 建分组缺 `price_multiplier`（字符串）/ `confirm_same_target` | 后端只报「请求错误」，不说缺哪个 |
| 4 | deepseek 的 `base_url` 带了 `/anthropic` | SDK 自己拼 `/anthropic/v1/messages`，带尾巴拼两遍 → 404 |
| 5 | 改模型清单当成追加 | `PUT /api/groups/<id>/models` 是**全量替换**，漏写的模型会被删 |

以上 5 条脚本都已处理，手动调 API 时需要自己注意。

## 许可证

[MIT](LICENSE)
