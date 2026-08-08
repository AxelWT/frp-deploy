#!/usr/bin/env bash
set -euo pipefail

# 切换到脚本所在目录,确保能找到 docker-compose.yml
cd "$(dirname "$0")"

COMPOSE="docker compose"
NAME="pi-web"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  start           构建镜像并启动容器 (docker compose up -d --build)
  stop            停止容器
  restart         重启容器(不重新读取 docker-compose.yml)
  recreate        重建容器(应用 environment 等配置变更)
  status          查看容器状态
  logs            跟踪日志 (Ctrl+C 退出)
  update <ver>    升级 pi-web 版本,例如: ./pi-web.sh update 0.11.0
  clean           停止并删除容器 (保留镜像与卷)
EOF
}

check_running() {
    docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null | grep -q true
}

# 预检:确保宿主机挂载源目录存在,否则 Docker 会以 root 创建导致归属异常
precheck() {
    mkdir -p "$HOME/.pi" "$HOME/.pi-web"
}

case "${1:-}" in
    start)
        precheck
        $COMPOSE up -d --build
        echo "已启动。访问 http://127.0.0.1:30141"
        echo "查看日志: $0 logs"
        ;;
    stop)
        $COMPOSE stop
        echo "已停止。"
        ;;
    restart)
        $COMPOSE restart
        echo "已重启。"
        ;;
    recreate)
        $COMPOSE up -d
        echo "已根据当前 docker-compose.yml 重建容器(应用 environment 等配置变更)。"
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
            echo "用法: $0 update <version>,例如: $0 update 0.11.0" >&2
            exit 1
        fi
        # macOS sed 需要 -i '' ; 同步修改 build.args.PI_WEB_VERSION 与 image tag 两处
        sed -i '' -E "s|PI_WEB_VERSION: [^[:space:]]+|PI_WEB_VERSION: ${VER}|" docker-compose.yml
        sed -i '' -E "s|image: local/pi-web:[^[:space:]]+|image: local/pi-web:${VER}|" docker-compose.yml
        echo "compose 已更新为 ${VER},重建镜像并启动..."
        precheck
        $COMPOSE up -d --build
        echo "升级完成。访问 http://127.0.0.1:30141"
        ;;
    clean)
        $COMPOSE down
        echo "已清理容器(镜像与卷保留)。"
        echo "如需删除镜像: docker rmi local/pi-web:<ver>"
        ;;
    *)
        usage
        exit 1
        ;;
esac
