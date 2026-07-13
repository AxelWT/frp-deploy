#!/usr/bin/env bash
set -euo pipefail

# 切换到脚本所在目录,确保能找到 docker-compose.yml
cd "$(dirname "$0")"

COMPOSE="docker compose"
CONF="/etc/frp/frpc.toml"
NAME="frpc"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  start           启动容器 (docker compose up -d)
  stop            停止容器
  restart         重启容器
  status          查看容器状态 + frpc 代理状态
  logs            跟踪日志 (Ctrl+C 退出)
  reload          热重载配置 (需启用 Admin UI)
  update <ver>    升级版本,例如: ./frpc.sh update v0.71.0
  clean           停止并删除容器 (保留配置与镜像)
EOF
}

check_running() {
    docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null | grep -q true
}

case "${1:-}" in
    start)
        $COMPOSE up -d
        echo "已启动。查看日志: $0 logs"
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
        echo "--- frpc 代理状态 ---"
        if check_running; then
            docker exec "$NAME" frpc status -c "$CONF" 2>&1 || echo "(获取代理状态失败)"
        else
            echo "容器未运行"
        fi
        ;;
    logs)
        $COMPOSE logs -f
        ;;
    reload)
        if ! check_running; then
            echo "错误: 容器未运行" >&2
            exit 1
        fi
        docker exec "$NAME" frpc reload -c "$CONF" 2>&1 \
            && echo "重载成功" \
            || echo "重载失败: 请确认 frpc.toml 中已启用 webServer 段" >&2
        ;;
    update)
        VER="${2:-}"
        if [ -z "$VER" ]; then
            echo "用法: $0 update <version>,例如: $0 update v0.71.0" >&2
            exit 1
        fi
        # 在 macOS 上 sed 需要 -i ''
        sed -i '' -E "s|image: ghcr.io/fatedier/frpc:v[0-9.]+|image: ghcr.io/fatedier/frpc:${VER}|" docker-compose.yml
        echo "compose 已更新为 ${VER},拉取镜像并重建..."
        $COMPOSE up -d
        echo "升级完成。"
        ;;
    clean)
        $COMPOSE down
        echo "已清理容器(配置与镜像保留)。"
        ;;
    *)
        usage
        exit 1
        ;;
esac
