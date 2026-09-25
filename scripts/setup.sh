#!/bin/bash
# gpt-load 一键部署：起 docker 服务
# 用法: bash setup.sh [DATA_DIR] [PORT]
# 示例: bash setup.sh /ws/dev/services/gpt-load 3001
set -euo pipefail

DATA_DIR="${1:-./gpt-load-data}"
PORT="${2:-3001}"
IMAGE="ghcr.io/tbphp/gpt-load:2"

echo "=== gpt-load 一键部署 ==="
echo "DATA_DIR: $DATA_DIR"
echo "PORT:     $PORT"
echo "IMAGE:    $IMAGE"
echo

# ── 先确认：要不要在这台机器上装 ────────────────────────────────
read -r -p "确认在当前机器部署 gpt-load 到 $DATA_DIR 吗？输入 yes 继续: " confirm
[ "$confirm" = "yes" ] || { echo "已取消。"; exit 0; }

# ── 坑一：data 目录属主必须是容器 uid 10001 ─────────────────────
# securefile 校验 stat.Uid == euid，bind mount 宿主目录（uid 1000）直接 EPERM 崩溃循环。
# 这里先建目录再 chown，再起容器。
mkdir -p "$DATA_DIR"
if [ "$(stat -c '%u' "$DATA_DIR" 2>/dev/null || stat -f '%u' "$DATA_DIR" 2>/dev/null)" != "10001" ]; then
  echo "[1/4] 修正 data 目录属主为 10001（容器 uid）..."
  sudo chown -R 10001:10001 "$DATA_DIR"
fi

# ── 写 docker-compose.yml ──────────────────────────────────────
cat > docker-compose.yml <<'EOF'
services:
  gpt-load:
    image: ghcr.io/tbphp/gpt-load:2
    container_name: gpt-load
    ports:
      - "3001:3001"
    environment:
      HOST: 0.0.0.0
      PORT: 3001
      DATA_DIR: /app/data
    restart: always
    volumes:
      - ./data:/app/data
    stop_grace_period: 15s
    healthcheck:
      test: wget -q --spider -T 10 -O /dev/null http://localhost:3001/health
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
EOF

echo "[2/4] 拉取镜像..."
docker pull "$IMAGE"

echo "[3/4] 启动容器..."
docker compose up -d

echo "[4/4] 验证服务..."
sleep 5
if curl -sf --max-time 10 "http://localhost:${PORT}/health" >/dev/null 2>&1; then
  echo "✓ gpt-load 已启动，健康检查通过"
  echo
  echo "管理 UI:  http://localhost:${PORT}"
  echo "首次登录用 AUTH_KEY（见 credentials.txt，权限 600）"
else
  echo "✗ 健康检查未通过，查看日志：docker logs gpt-load --tail 30"
  exit 1
fi
