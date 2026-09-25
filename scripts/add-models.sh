#!/bin/bash
# 给分组挂模型 + 设别名
# 用法: bash add-models.sh <GROUP_ID> '<JSON_MODELS>'
# 示例:
#   bash add-models.sh 1 '[{"id":"k3","alias":"k3[1m]","alias_enabled":true},{"id":"k3-256k","alias":"","alias_enabled":false}]'
set -euo pipefail

AUTH_KEY="${GPT_LOAD_AUTH_KEY:?请设置 GPT_LOAD_AUTH_KEY（管理密钥，见 credentials.txt）}"
BASE="${GPT_LOAD_BASE:-http://localhost:3001}"

GROUP_ID="${1:?用法: bash add-models.sh <GROUP_ID> '<JSON_MODELS>'}"
MODELS_JSON="${2:?}"

# ── 坑四：改模型清单是全量替换，不是追加 ────────────────────────
# 漏写的模型会被删掉。先读现有清单，提示用户确认。
echo "=== 当前分组 $GROUP_ID 的模型清单 ==="
curl -sS --max-time 15 -H "Authorization: Bearer $AUTH_KEY" \
  "$BASE/api/groups/$GROUP_ID/models" | head -c 500
echo
echo

# 确认后再替换（防止误删）
read -r -p "确认要全量替换模型清单吗？输入 yes 继续: " confirm
[ "$confirm" = "yes" ] || { echo "已取消。"; exit 0; }

BODY=$(cat <<EOF
{"models": $MODELS_JSON}
EOF
)

RESPONSE=$(curl -sS --max-time 15 -w "\n%{http_code}" \
  -X PUT "$BASE/api/groups/$GROUP_ID/models" \
  -H "Authorization: Bearer $AUTH_KEY" \
  -H "Content-Type: application/json" \
  -d "$BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY_OUT=$(echo "$RESPONSE" | sed '$d')

echo "HTTP $HTTP_CODE"
echo "$BODY_OUT" | head -c 400
echo

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "✓ 模型清单已更新"
else
  echo "✗ 更新失败。常见原因："
  echo "  - 模型 id 不存在（先 GET /api/models 看全局目录）"
  echo "  - JSON 格式错误（检查引号/逗号）"
  echo "  - 全量替换：漏写的模型会被删，确认是否漏写"
  exit 1
fi
