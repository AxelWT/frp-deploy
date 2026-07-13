# frps 服务端配置模板(云服务器 Linux + Docker)
# 占位符由 GitHub Actions 通过 envsubst 渲染,密钥不入库
# 本地调试可:export FRPS_AUTH_TOKEN=... && envsubst < frps.toml.tpl > frps.toml

# === 监听 ===
bindAddr = "0.0.0.0"
bindPort = 7000                     # frpc 连接端口
vhostHTTPPort = ${FRPS_VHOST_HTTP_PORT}     # HTTP 代理流量入口(NPM 转发到此),由 Secret 渲染
vhostHTTPSPort = ${FRPS_VHOST_HTTPS_PORT}   # HTTPS 代理流量入口(备用),由 Secret 渲染

# === 认证 ===
auth.method = "token"
auth.token = "${FRPS_AUTH_TOKEN}"      # 由 GitHub Secret FRPS_AUTH_TOKEN 渲染,需与 frpc 一致

# === Dashboard ===
webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "${FRPS_ADMIN_USER}"          # 由 GitHub Secret FRPS_ADMIN_USER 渲染
webServer.password = "${FRPS_ADMIN_PASSWORD}"  # 由 GitHub Secret FRPS_ADMIN_PASSWORD 渲染

# === 日志 ===
log.to = "console"                  # 输出到控制台,便于 docker logs 查看
log.level = "info"
log.maxDays = 3

# === TLS(可选,强制 frpc 用 TLS 连接)===
transport.tls.force = true
