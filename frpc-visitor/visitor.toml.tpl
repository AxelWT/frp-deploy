# frpc-visitor 配置模板(访问端 / P2P 直连发起方)
# 占位符 ${VAR} 由本地 envsubst 渲染,或直接 cp 后手动替换
# 本地调试可:
#   export FRPC_SERVER_ADDR=1.2.3.4 FRPC_AUTH_TOKEN=xxx \
#          FRPC_ADMIN_USER=admin FRPC_ADMIN_PASSWORD=xxx FRPC_P2P_SECRET=xxx
#   envsubst < visitor.toml.tpl > visitor.toml
# 渲染后的 visitor.toml 含真实密钥,已被 .gitignore 排除,请勿入库

# === frps 服务端连接(与被访问端 Mac frpc 指向同一台 frps) ===
serverAddr = "${FRPC_SERVER_ADDR}"        # frps 公网 IP,与 frpc 端一致
serverPort = 7000                         # frps 的 bindPort

# === 认证(与 frpc 端完全一致) ===
auth.method = "token"
auth.token = "${FRPC_AUTH_TOKEN}"         # 与 frpc 端的 auth.token 一致

# === 日志 ===
log.to = "console"                        # 输出到控制台,便于 docker logs 查看
log.level = "info"
log.maxDays = 3

# === Client Admin UI(用于热重载,默认启用) ===
# 容器内监听 0.0.0.0:7400,通过 docker ports 映射到宿主机 127.0.0.1:7400(见 docker-compose.yml)
webServer.addr = "0.0.0.0"
webServer.port = 7400
webServer.user = "${FRPC_ADMIN_USER}"
webServer.password = "${FRPC_ADMIN_PASSWORD}"

# ==========================================================================
# P2P 访问规则:xtcp 优先 + stcp 自动兜底
#   - xtcp: 直连打洞,成功后流量在两个 frpc 之间直传,不经 frps
#   - fallbackTo: xtcp 连接超时(默认 4s)后自动回退到 stcp(经 frps 中转,但端到端加密)
#   - serverName 必须与 frpc 端 [[proxies]] name 完全一致
#   - secretKey 必须与 frpc 端对应 proxy 的 secretKey 完全一致
#   - bindAddr = "0.0.0.0":容器内必须绑 0.0.0.0 才能被 docker 端口转发命中;
#     "仅本机访问"由 docker-compose.yml 的 127.0.0.1: 前缀实现
#   - bindPort 是访问端本地监听端口,浏览器/客户端访问 127.0.0.1:<bindPort>
#     即等同于访问 Mac 上的对应服务
# ==========================================================================

# === app1 P2P 访问 ===
# xtcp 优先,失败自动 fallback 到 app1-stcp(被访问端 frpc 已配置该 stcp proxy)
[[visitors]]
name = "app1-visitor"
type = "xtcp"
serverName = "app1-p2p"                    # 对应 frpc 端 xtcp proxy 的 name
secretKey = "${FRPC_P2P_SECRET}"           # 对应 frpc 端 FRPC_P2P_SECRET
bindAddr = "0.0.0.0"                       # 容器内绑 0.0.0.0,宿主机侧由 compose 限制为 127.0.0.1
bindPort = 12026                           # 访问端本地端口,可自定义(避开占用端口)
fallbackTo = "app1-stcp"                   # xtcp 失败时回退到 stcp(指向被访问端的 stcp proxy name)
fallbackTimeoutMs = 4000                   # xtcp 连接超时 4s 后触发 fallback(留足 NAT 打洞时间)

# === app2 P2P 访问(复制此段可添加更多 P2P 访问规则) ===
[[visitors]]
name = "app2-visitor"
type = "xtcp"
serverName = "app2-p2p"
secretKey = "${FRPC_P2P_SECRET}"
bindAddr = "0.0.0.0"
bindPort = 12028
fallbackTo = "app2-stcp"
fallbackTimeoutMs = 4000
