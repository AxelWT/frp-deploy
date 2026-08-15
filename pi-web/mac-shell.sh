#!/bin/sh
# pi-web 网页终端 → Mac 宿主机 shell
# pty-server 以项目目录为 cwd 启动本脚本；把容器路径映射回 Mac 路径
MAC_CWD=$(printf '%s' "$PWD" | sed 's#^/root#/Users/allen#')
exec ssh -tt \
  -i /ssh/pi-web-terminal \
  -o StrictHostKeyChecking=accept-new \
  -o BatchMode=yes \
  -o IdentitiesOnly=yes \
  allen@host.docker.internal \
  "cd '$MAC_CWD' 2>/dev/null; exec \$SHELL -l"
