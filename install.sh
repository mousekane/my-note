#!/usr/bin/env bash
# MYNOTE 私密笔记 - 一键安装脚本
#
# 用法 (二选一):
#   curl -fsSL https://raw.githubusercontent.com/mousekane/my-note/main/install.sh | bash
#   bash install.sh
#
# 可选环境变量:
#   MYNOTE_PORT      对外端口, 默认 8787
#   MYNOTE_PASSWORD  初始登录密码 (同时也是 API 密钥), 默认 admin
#   MYNOTE_IMAGE     镜像地址, 默认 ghcr.io/mousekane/my-note:latest
#   MYNOTE_CONTAINER 容器名, 默认 mynote
#   MYNOTE_VOLUME    数据卷名, 默认 mynote-data
#
# 装完后打开 http://本机IP:端口, 密码就是 MYNOTE_PASSWORD (默认 admin)。
# 登录后请立刻改密码: 右上角三条杠 → 设置 → 修改密码。
set -euo pipefail

IMAGE="${MYNOTE_IMAGE:-ghcr.io/mousekane/my-note:latest}"
PORT="${MYNOTE_PORT:-8787}"
PASSWORD="${MYNOTE_PASSWORD:-admin}"
CONTAINER_NAME="${MYNOTE_CONTAINER:-mynote}"
VOLUME_NAME="${MYNOTE_VOLUME:-mynote-data}"

# root 才能直接跑 docker; 不是 root 就用 sudo (没有 sudo 就报错退出)
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

need() { command -v "$1" >/dev/null 2>&1; }

echo "[mynote] 一键安装开始"

# 1. 没装 Docker 就装一个 (Debian / Ubuntu / 树莓派系统走官方安装脚本)
if ! need docker; then
  echo "[mynote] 没找到 Docker, 正在安装..."
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "${ID:-}" in
      debian|ubuntu|raspbian)
        need curl || $SUDO apt-get update -qq && $SUDO apt-get install -y -qq curl
        curl -fsSL https://get.docker.com | $SUDO sh
        ;;
      *)
        echo "[mynote] 这个系统不会自动装 Docker, 请先手动装好 Docker 再跑这个脚本:"
        echo "  https://docs.docker.com/engine/install/"
        exit 1
        ;;
    esac
  else
    echo "[mynote] 认不出这个系统, 请先手动装好 Docker 再跑这个脚本:"
    echo "  https://docs.docker.com/engine/install/"
    exit 1
  fi
fi

# 2. 确保 Docker 服务在跑 (有 systemd 的系统)
if need systemctl; then
  $SUDO systemctl start docker 2>/dev/null || true
fi
$SUDO docker info >/dev/null 2>&1 || {
  echo "[mynote] Docker 装好了但服务没起来, 请先启动 Docker 再跑这个脚本"
  exit 1
}

# 3. 拉镜像
echo "[mynote] 拉取镜像 $IMAGE ..."
$SUDO docker pull "$IMAGE"

# 4. 已有同名容器就先删掉 (数据在卷里, 不会丢)
if $SUDO docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  echo "[mynote] 删掉已有的容器 $CONTAINER_NAME (数据保留在卷 $VOLUME_NAME 里)"
  $SUDO docker rm -f "$CONTAINER_NAME" >/dev/null
fi

# 5. 启动
echo "[mynote] 启动容器 (端口 $PORT, 数据卷 $VOLUME_NAME)..."
$SUDO docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "$PORT:8787" \
  -e "NOTES_PASSWORD=$PASSWORD" \
  -e "NOTES_API_KEY=$PASSWORD" \
  -e "NOTES_SESSION_SECRET=$PASSWORD" \
  -v "$VOLUME_NAME:/app/data" \
  "$IMAGE" >/dev/null

# 6. 等它起来, 验一下健康检查
echo "[mynote] 等服务启动..."
for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if curl -fsS "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1; then
  echo
  echo "[mynote] 装好了!"
  echo "  打开: http://localhost:$PORT (同一台机器)"
  echo "  或:   http://本机IP:$PORT (手机、别的电脑)"
  echo "  密码: $PASSWORD"
  echo "  登录后请立刻改密码: 右上角三条杠 → 设置 → 修改密码"
  echo "  看日志: docker logs -f $CONTAINER_NAME"
  echo "  停止:   docker stop $CONTAINER_NAME / 启动: docker start $CONTAINER_NAME"
else
  echo "[mynote] 容器起来了, 但健康检查没通过, 看看日志:"
  $SUDO docker logs --tail 30 "$CONTAINER_NAME"
  exit 1
fi
