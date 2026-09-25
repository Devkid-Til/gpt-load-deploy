# gpt-load 部署脚本

自托管 AI 网关 [gpt-load](https://github.com/tbphp/gpt-load) 的部署脚本集合。

gpt-load 是 Go 单二进制 + SQLite 的轻量 AI 网关：多渠道多凭据统一接入，含密钥与订阅账号、调度容错、日志与用量。

## 前置

- Docker + docker compose
- 管理密钥 `AUTH_KEY`（首次登录管理 UI 时生成，写进 `credentials.txt`）

## 用法

### 1. 一键起服务

```bash
# 默认: DATA_DIR=./gpt-load-data, PORT=3001
bash scripts/setup.sh

# 自定义
bash scripts/setup.sh /path/to/data 3001
```

### 2. 建分组

```bash
# 先设置管理密钥
export GPT_LOAD_AUTH_KEY="<你的 AUTH_KEY>"

# 建 Kimi 分组（Anthropic 协议）
bash scripts/create-group.sh kimi-code anthropic https://api.kimi.com/coding

# 建 DeepSeek 分组
bash scripts/create-group.sh deepseek deepseek https://api.deepseek.com

# 建本地 Ollama 分组
bash scripts/create-group.sh ollama-local openai_compatible http://<宿主机IP>:11500/v1
```

### 3. 挂模型 + 设别名

```bash
# 注意：这是全量替换，漏写的模型会被删掉，脚本会先提示确认
bash scripts/add-models.sh <GROUP_ID> '[{"id":"k3","alias":"k3[1m]","alias_enabled":true}]'
```

### 4. 验证

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

## 踩过的坑（都验证过）

1. **data 目录属主必须是容器 uid 10001** —— bind mount 宿主目录（uid 1000）直接 EPERM 崩溃循环
2. **建分组必须带 Idempotency-Key 头** —— 否则 428
3. **建分组必填 price_multiplier（字符串）和 confirm_same_target** —— 后端报错只说「请求错误」
4. **deepseek 的 base_url 不带 /anthropic** —— SDK 按协议自己拼 `/anthropic/v1/messages`，带尾巴会拼两遍报 404
5. **改模型清单是全量替换** —— `PUT /api/groups/<id>/models` 漏写的模型会被删掉

## 许可证

MIT
