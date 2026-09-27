#!/usr/bin/env bash
set -euo pipefail

# 切换到脚本所在目录,确保能找到 docker-compose.yml 与 .env
cd "$(dirname "$0")"

COMPOSE="docker compose"
NAME="chromium"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  start           启动容器 (docker compose up -d)
  stop            停止容器
  restart         重启容器
  status          查看容器状态
  logs            跟踪日志 (Ctrl+C 退出)
  update <ver>    升级版本,例如: ./chrome.sh update b1ee1dc8-ls55
                  (标签见 https://hub.docker.com/r/linuxserver/chromium/tags,形如 <hash>-lsNN)
  clean           停止并删除容器 (保留 config 目录与镜像)
EOF
}

case "${1:-}" in
    start)
        $COMPOSE up -d
        echo "已启动。本地验证: http://127.0.0.1:3000 (登录: .env 中 CHROME_USER/CHROME_PASSWORD)"
        ;;
    stop)
        $COMPOSE stop
        echo "已停止。"
        ;;
    restart)
        $COMPOSE restart
        echo "已重启。"
        ;;
    status)
        $COMPOSE ps
        ;;
    logs)
        $COMPOSE logs -f
        ;;
    update)
        VER="${2:-}"
        if [ -z "$VER" ]; then
            echo "用法: $0 update <version>,例如: $0 update b1ee1dc8-ls55" >&2
            exit 1
        fi
        # 在 macOS 上 sed 需要 -i '';标签形如 <commithash>-lsNN
        sed -i '' -E "s|image: lscr.io/linuxserver/chromium:[a-zA-Z0-9._-]+|image: lscr.io/linuxserver/chromium:${VER}|" docker-compose.yml
        echo "compose 已更新为 ${VER},拉取镜像并重建..."
        $COMPOSE up -d
        echo "升级完成(config 目录保留,浏览器配置不丢失)。"
        ;;
    clean)
        $COMPOSE down
        echo "已清理容器(config 目录与镜像保留)。"
        ;;
    *)
        usage
        exit 1
        ;;
esac
