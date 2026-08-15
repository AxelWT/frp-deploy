FROM node:22-alpine

# pi-web 版本由 docker-compose 的 build.args 注入；fallback 到 latest 以便单独 build
ARG PI_WEB_VERSION=latest

# node-pty 无 linux/arm64 prebuild,需 node-gyp 现场编译,依赖 python3/make/g++
# apk 换清华源、npm 换 npmmirror,避免默认源在国内网络极慢
# bash: 终端功能默认 shell 为 bash,Alpine 基础镜像不带
# openssh-client: mac-shell 终端通过 SSH 连回 Mac 宿主机
RUN sed -i 's#https://dl-cdn.alpinelinux.org#https://mirrors.tuna.tsinghua.edu.cn#g' /etc/apk/repositories \
 && apk add --no-cache libstdc++ bash openssh-client \
 && apk add --no-cache --virtual .build-deps python3 make g++ \
 && npm install -g @axello/pi-web@${PI_WEB_VERSION} --registry=https://registry.npmmirror.com \
 && mkdir -p /root/.pi /root/.pi-web \
 && apk del .build-deps

# 网页终端的 shell: SSH 包装脚本,连到 Mac 宿主机而非容器内
COPY mac-shell.sh /usr/local/bin/mac-shell
RUN chmod +x /usr/local/bin/mac-shell

# 终端功能依赖 process.cwd(): 从 cwd 解析 node-pty,并拼接 bin/pty-server.js,
# 必须把工作目录设到包目录,否则终端报 "node-pty native module not available"
# 0.10.5 起终端走同源代理(/api/terminal/socket.io),pty-server 只需绑容器内 loopback
WORKDIR /usr/local/lib/node_modules/@axello/pi-web

# 容器内必绑 0.0.0.0,否则端口映射命中不到;禁用浏览器自启(容器无 GUI)
ENV PI_WEB_HOSTNAME=0.0.0.0 \
    PI_WEB_NO_OPEN=1 \
    PTY_SHELL=/bin/bash

EXPOSE 30141

CMD ["pi-web"]
