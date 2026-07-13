# frpc 客户端配置模板(macOS Docker Desktop + HTTP 代理)
# 占位符 ${VAR} 由本地 envsubst 渲染,或直接 cp 后手动替换
# 本地调试可:
#   export FRPC_SERVER_ADDR=1.2.3.4 FRPC_AUTH_TOKEN=xxx FRPC_ADMIN_USER=admin FRPC_ADMIN_PASSWORD=xxx
#   envsubst < frpc.toml.tpl > frpc.toml
# 渲染后的 frpc.toml 含真实密钥,已被 .gitignore 排除,请勿入库

# === frps 服务端连接 ===
serverAddr = "${FRPC_SERVER_ADDR}"        # frps 公网 IP
serverPort = 7000                         # frps 的 bindPort

# === 认证 ===
auth.method = "token"                     # 显式声明,与 frps 保持一致
auth.token = "${FRPC_AUTH_TOKEN}"         # 必须与 frps 的 auth.token 完全一致

# === 日志 ===
log.to = "console"                        # 输出到控制台,便于 docker logs 查看
log.level = "info"
log.maxDays = 3

# === TLS:v0.50+ 默认已启用,无需配置 ===
# transport.tls.enable = true

# === Client Admin UI(用于热重载,默认启用) ===
# 仅本地 7400 访问,请勿通过 [[proxies]] 暴露到公网
webServer.addr = "0.0.0.0"
webServer.port = 7400
webServer.user = "${FRPC_ADMIN_USER}"
webServer.password = "${FRPC_ADMIN_PASSWORD}"

# === 代理 1:HTTP Web 服务 ===
[[proxies]]
name = "app1-frp"
type = "http"
localIP = "host.docker.internal"                # 关键:容器通过此名称访问 Mac 宿主机
localPort = 2026                                # TODO: 替换为 Mac 上 Web 服务实际端口
customDomains = ["app1.your-domain.com"]        # TODO: 替换为已解析到 frps 的域名

# 可选:HTTP Basic Auth 保护
# httpUser = "admin"
# httpPassword = "secret"

# 可选:健康检查
# healthCheck.type = "http"
# healthCheck.path = "/status"
# healthCheck.intervalSeconds = 10
# healthCheck.maxFailed = 3
# healthCheck.timeoutSeconds = 3

# === 代理 2:HTTP Web 服务(复制此段可添加更多代理)===
[[proxies]]
name = "app2-frp"
type = "http"
localIP = "host.docker.internal"
localPort = 8004                                # TODO: 替换为 Mac 上 Web 服务实际端口
customDomains = ["app2.your-domain.com"]        # TODO: 替换为已解析到 frps 的域名
