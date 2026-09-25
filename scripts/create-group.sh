#!/bin/bash
# 创建 gpt-load 分组（channel）
# 用法: bash create-group.sh <NAME> <CHANNEL_ID> <BASE_URL>
# 示例:
#   bash create-group.sh kimi-code anthropic https://api.kimi.com/coding
#   bash create-group.sh deepseek deepseek https://api.deepseek.com
#   bash create-group.sh ollama-local openai_compatible http://10.211.55.2:11500/v1
set -euo pipefail

AUTH_KEY="${GPT_LOAD_AUTH_KEY:?请设置 GPT_LOAD_AUTH_KEY（管理密钥，见 credentials.txt）}"
BASE="${GPT_LOAD_BASE:-http://localhost:3001}"

NAME="${1:?用法: bash create-group.sh <NAME> <CHANNEL_ID> <BASE_URL>}"
CHANNEL_ID="${2:?}"
BASE_URL="${3:?}"

# ── 坑二：建分组必须带 Idempotency-Key 头，否则 428 ──────────────
# 用随机 UUID 保证每次请求独立，重复提交也不会重复建组
IDEMPOTENCY_KEY="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || echo "$(date +%s)-$$")"

# ── 坑三：必填 price_multiplier（字符串）和 confirm_same_target ──
# 后端报错只说「请求错误」，缺哪个不说。正确载荷格式看前端 web/src/frontends/modern/api/group-create.ts
BODY=$(cat <<EOF
{
  "name": "$NAME",
  "channel_id": "$CHANNEL_ID",
  "connection_type": "api_key",
  "params": {"base_url": "$BASE_URL"},
  "price_multiplier": "1",
  "confirm_same_target": true
}
EOF
)

echo "=== 创建分组 ==="
echo "name:        $NAME"
echo "channel_id:  $CHANNEL_ID"
echo "base_url:    $BASE_URL"
echo

RESPONSE=$(curl -sS --max-time 15 -w "\n%{http_code}" \
  -X POST "$BASE/api/groups" \
  -H "Authorization: Bearer $AUTH_KEY" \
  -H "Idempotency-Key: $IDEMPOTENCY_KEY" \
  -H "Content-Type: application/json" \
  -d "$BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY_OUT=$(echo "$RESPONSE" | sed '$d')

echo "HTTP $HTTP_CODE"
echo "$BODY_OUT" | head -c 500
echo

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  GROUP_ID=$(echo "$BODY_OUT" | grep -oE '"id":[0-9]+' | head -1 | cut -d: -f2)
  echo "✓ 分组创建成功，id=$GROUP_ID"
  echo "  下一步：bash add-models.sh $GROUP_ID"
else
  echo "✗ 创建失败。常见原因："
  echo "  - 没带 Idempotency-Key（428）"
  echo "  - price_multiplier 不是字符串"
  echo "  - 同名分组已存在（confirm_same_target）"
  exit 1
fi
