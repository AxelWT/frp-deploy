FROM node:22-alpine

# pi-web 版本由 docker-compose 的 build.args 注入；fallback 到 latest 以便单独 build
ARG PI_WEB_VERSION=latest
RUN npm install -g @axello/pi-web@${PI_WEB_VERSION} \
 && mkdir -p /root/.pi /root/.pi-web

# 容器内必绑 0.0.0.0,否则端口映射命中不到;禁用浏览器自启(容器无 GUI)
ENV PI_WEB_HOSTNAME=0.0.0.0 \
    PI_WEB_NO_OPEN=1

EXPOSE 30141

CMD ["pi-web"]
