# frp-deploy

> Docker Compose-based one-click deployment for [frp](https://github.com/fatedier/frp) (fast reverse proxy).
> 基于 Docker Compose 的 frp 内网穿透一键部署方案,封装 frps(服务端)与 frpc(客户端)的配置、管理脚本与 CI/CD 流程。

## ✨ Features / 特性

- **双端 Docker 化** — frps / frpc 均通过 docker-compose 管理,`up -d` 即可运行
- **管理脚本封装** — `start` / `stop` / `restart` / `status` / `logs` / `reload` / `update` / `clean` 一键调用
- **CI/CD 自动部署** — frps 服务端通过 GitHub Actions 自动部署到云服务器,密钥走 Secrets 不入库
- **配置模板化** — `frps.toml.tpl` + `envsubst` 渲染,真实 token / 密码仅存于 GitHub Secrets
- **Mac 友好** — frpc 客户端跑在 Docker Desktop,通过 `host.docker.internal` 反代宿主机服务
- **版本可升级** — 脚本支持 `update <ver>` 一键升级镜像版本

## 🎯 解决的问题

手动部署 frp 常见痛点,本项目逐一化解:

| 痛点 | 本项目方案 |
|---|---|
| 命令行长选项难记,易出错 | `frps.sh` / `frpc.sh` 封装常用命令 |
| systemd 单元手写繁琐 | docker-compose `restart: unless-stopped` 托管 |
| 配置散落多处,迁移困难 | 整目录 `rsync` 同步,配置即代码 |
| 密钥容易误提交仓库 | `.toml.tpl` 模板 + GitHub Secrets + `envsubst` 渲染 |
| 升级 frp 版本要手改 compose | `./frps.sh update v0.71.0` 一行搞定 |
| 服务端每次改配置都要 SSH | push 到 main 自动触发部署 |

## 🏗 Architecture / 架构图

```
                          Public Internet / 公网
                                 │
   ┌─────────────────────────────┼─────────────────────────────┐
   │                             ▼                             │
   │   ┌─────────────────────────────────────────────────┐     │
   │   │  Cloud Server / 云服务器 (<your-server-ip>)     │     │
   │   │                                                 │     │
   │   │   ┌───────────┐         ┌───────────────────┐   │     │
   │   │   │  Nginx    │  HTTP   │  frps container   │   │     │
   │   │   │  Proxy    │◀───────│  :7000 (bind)     │   │     │
   │   │   │  Manager  │  :8080  │  :7500 (dashboard)│   │     │
   │   │   │  :80/:443 │         │  :8080 (vhost)    │   │     │
   │   │   └─────┬─────┘         │  :8443 (vhostTLS) │   │     │
   │   │         │               └────────▲──────────┘   │     │
   │   │         │                        │              │     │
   │   │         ▼                        │ frp tunnel   │     │
   │   │   app.your-domain.com             │              │     │
   │   └───────────────────────────────────┼──────────────┘     │
   │                                       │                    │
   └───────────────────────────────────────┼────────────────────┘
                                           │
   ┌───────────────────────────────────────┼────────────────────┐
   │  Local Mac / 本地 Mac                  │                    │
   │                                       │                    │
   │   ┌───────────────────┐    ┌──────────┴───────────┐        │
   │   │  Local Service    │    │  frpc container      │        │
   │   │  (e.g. :2026)     │◀───│  connects to frps    │        │
   │   │                   │    │  host.docker.internal│        │
   │   │  Local Service 2  │◀───│  :7400 (admin UI)    │        │
   │   │  (e.g. :8004)     │    └──────────────────────┘        │
   │   └───────────────────┘                                    │
   └────────────────────────────────────────────────────────────┘
```

**流量路径**:用户访问 `app.your-domain.com` → NPM 443 → NPM 转发到 `frps:8080` → frps 通过 frp 隧道转发到本地 frpc → frpc 通过 `host.docker.internal` 访问 Mac 上的本地服务。

## 📁 Project Structure / 项目结构

```
frp-deploy/
├── frps/                              # 服务端(部署到云服务器)
│   ├── docker-compose.yml             # frps 容器定义,暴露 7000/7500/8080/8443
│   ├── frps.toml.tpl                  # 配置模板,占位符 ${VAR} 由 CI 渲染
│   └── frps.sh                        # 管理脚本(start/stop/update/...)
├── frpc/                              # 客户端(部署到本地 Mac)
│   ├── docker-compose.yml             # frpc 容器定义,暴露 7400(admin UI)
│   ├── frpc.toml.tpl                  # 客户端配置模板(含代理规则)
│   └── frpc.sh                        # 管理脚本
├── .github/
│   └── workflows/
│       └── deploy-frps.yml            # frps 自动部署工作流
├── .gitignore                         # 排除渲染后的 frps.toml / frpc.toml(含密钥)
└── README.md
```

## 🚀 Quick Start / 快速开始

### Part 1: Server (frps) / 服务端部署

#### Option A: Manual first-time deploy / 手动首次部署

> 首次部署或无 GitHub 环境 时使用。

1. **上传 `frps/` 目录到服务器 `/app/frps/`**:

   ```bash
   # 本地执行
   rsync -avz frps/ root@<your-server-ip>:/app/frps/
   ```

2. **在服务器上渲染配置**(替换占位符为真实值):

   ```bash
   ssh root@<your-server-ip>
   cd /app/frps
   export FRPS_AUTH_TOKEN="<your-auth-token>"        # 与 frpc 保持一致
   export FRPS_ADMIN_USER="<your-admin-user>"
   export FRPS_ADMIN_PASSWORD="<your-admin-password>"
   export FRPS_VHOST_HTTP_PORT="8080"               # NPM 转发目标端口,按需修改
   export FRPS_VHOST_HTTPS_PORT="8443"              # HTTPS 代理端口,按需修改
   envsubst < frps.toml.tpl > frps.toml
   chmod 600 frps.toml
   ```

3. **启动**:

   ```bash
   ./frps.sh start
   ```

4. **验证**:浏览器访问 `http://<your-server-ip>:7500`,用上一步的账号密码登录 Dashboard。

#### Option B: GitHub Actions auto-deploy / CI 自动部署(推荐)

> 后续维护使用,改配置后 push 即自动部署。

1. **在 GitHub 仓库配置 Secrets**(`Settings → Secrets and variables → Actions`):

   | Secret 名 | 用途 | 示例值 |
   |---|---|---|
   | `SSH_HOST` | 服务器公网 IP | `1.2.3.4` |
   | `SSH_USER` | SSH 登录用户 | `root` |
   | `SSH_PORT` | SSH 端口 | `22` |
   | `SSH_PRIVATE_KEY` | SSH 私钥(全文) | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
   | `FRPS_AUTH_TOKEN` | frp 认证 token,需与 frpc 一致 | `long-random-string` |
   | `FRPS_ADMIN_USER` | Dashboard 用户名 | `admin` |
   | `FRPS_ADMIN_PASSWORD` | Dashboard 密码 | `strong-password` |
   | `FRPS_VHOST_HTTP_PORT` | HTTP 代理流量入口端口(NPM 转发目标) | `8080` |
   | `FRPS_VHOST_HTTPS_PORT` | HTTPS 代理流量入口端口(备用) | `8443` |

2. **触发部署**(二选一):
   - **自动**:push 到 `main` 分支且 `frps/**` 有变更
   - **手动**:仓库 `Actions` 页 → 选择 `Deploy frps` → `Run workflow`

3. **查看日志**:`Actions` 页面进入对应 run,展开 `Render config and (re)start container` 步骤,可看到容器状态和 Dashboard 探测结果。

### Part 2: Client (frpc) / 客户端部署

1. **渲染 `frpc.toml`**(二选一):

   **方式 A:envsubst 渲染**(若 Mac 已装 `gettext`,可 `brew install gettext`)

   ```bash
   cd frpc
   export FRPC_SERVER_ADDR="<your-server-ip>"        # frps 公网 IP
   export FRPC_AUTH_TOKEN="<your-auth-token>"         # 必须与 frps 的 FRPS_AUTH_TOKEN 一致
   export FRPC_ADMIN_USER="<your-admin-user>"         # frpc admin UI 用户名
   export FRPC_ADMIN_PASSWORD="<your-admin-password>" # frpc admin UI 密码
   envsubst < frpc.toml.tpl > frpc.toml
   ```

   **方式 B:手动编辑**(Mac 默认无 envsubst 时用)

   ```bash
   cd frpc
   cp frpc.toml.tpl frpc.toml
   # 然后用编辑器把 ${FRPC_SERVER_ADDR} 等占位符替换为真实值
   ```

   > 渲染后的 `frpc.toml` 含真实密钥,已被 `.gitignore` 排除,不会入库。

2. **编辑代理规则**(在渲染后的 `frpc.toml` 末尾):

   ```toml
   [[proxies]]
   name = "my-app-frp"
   type = "http"
   localIP = "host.docker.internal"        # Mac 容器访问宿主机的固定名称,勿改
   localPort = 2026                        # 改为 Mac 上 Web 服务实际端口
   customDomains = ["app.your-domain.com"] # 改为已解析到 frps 的域名
   ```

   复制整段 `[[proxies]]` 即可添加更多代理。

3. **启动**:

   ```bash
   ./frpc.sh start
   ```

4. **验证**:浏览器访问 `http://app.your-domain.com`,应看到本地服务的内容。

## ⚙️ Configuration Reference / 配置详解

### `frps.toml.tpl` 关键字段

| 字段 | 默认值 | 说明 |
|---|---|---|
| `bindAddr` | `0.0.0.0` | 监听地址,公网服务保持 0.0.0.0 |
| `bindPort` | `7000` | frpc 连接端口,客户端 `serverPort` 必须一致 |
| `vhostHTTPPort` | `${FRPS_VHOST_HTTP_PORT}` | HTTP 代理流量入口,由 Secret 渲染(默认 8080) |
| `vhostHTTPSPort` | `${FRPS_VHOST_HTTPS_PORT}` | HTTPS 代理流量入口,由 Secret 渲染(默认 8443) |
| `auth.token` | `${FRPS_AUTH_TOKEN}` | 认证 token,与 frpc 必须完全一致 |
| `webServer.addr` | `0.0.0.0` | Dashboard 监听地址 |
| `webServer.port` | `7500` | Dashboard 端口 |
| `webServer.user` | `${FRPS_ADMIN_USER}` | Dashboard 用户名 |
| `webServer.password` | `${FRPS_ADMIN_PASSWORD}` | Dashboard 密码 |
| `log.to` | `console` | 日志输出到控制台,便于 `docker logs` 查看 |
| `transport.tls.force` | (注释) | 取消注释可强制 frpc 用 TLS 连接 |

### `frpc.toml.tpl` 关键字段

| 字段 | 示例 | 说明 |
|---|---|---|
| `serverAddr` | `${FRPC_SERVER_ADDR}` | frps 公网 IP,渲染后为真实值 |
| `serverPort` | `7000` | 对应 frps 的 `bindPort` |
| `auth.method` | `token` | 认证方式,与 frps 保持一致 |
| `auth.token` | `${FRPC_AUTH_TOKEN}` | 与 frps 的 `auth.token` 必须一致 |
| `webServer.port` | `7400` | frpc admin UI,用于热重载,仅本地访问 |
| `webServer.user` | `${FRPC_ADMIN_USER}` | admin UI 用户名 |
| `webServer.password` | `${FRPC_ADMIN_PASSWORD}` | admin UI 密码 |
| `[[proxies]].localIP` | `host.docker.internal` | Mac 容器访问宿主机的固定名称,勿改 |
| `[[proxies]].localPort` | `2026` | Mac 上 Web 服务的实际端口 |
| `[[proxies]].customDomains` | `app.your-domain.com` | 已解析到 frps 服务器的域名 |
| `[[proxies]].type` | `http` | HTTP 反代用 http,需配合 NPM |

## 🛠 Management Scripts / 管理脚本

`frps.sh` 与 `frpc.sh` 命令完全对称,在各自目录下执行:

| 命令 | 作用 |
|---|---|
| `./frps.sh start` | 启动容器(`docker compose up -d`) |
| `./frps.sh stop` | 停止容器 |
| `./frps.sh restart` | 重启容器 |
| `./frps.sh status` | 查看容器状态 + frp 代理状态 |
| `./frps.sh logs` | 跟踪日志(`Ctrl+C` 退出) |
| `./frps.sh reload` | 热重载配置(需启用 Dashboard/admin UI) |
| `./frps.sh update <ver>` | 升级版本,如 `./frps.sh update v0.71.0` |
| `./frps.sh clean` | 停止并删除容器(保留配置与镜像) |

> frpc 把 `frps` 换成 `frpc` 即可,例如 `./frpc.sh start`。

## 🌐 Nginx Proxy Manager 配置

frps 的 `vhostHTTPPort` 是 8080,需要一个反向代理把 80/443 流量转发过去。推荐 [Nginx Proxy Manager](https://nginxproxymanager.com/):

> ⚠️ 若修改了 `FRPS_VHOST_HTTP_PORT` Secret,NPM 的 Forward Port 必须同步修改,否则 502。

1. **DNS**:将域名(如 `app.your-domain.com`)A 记录解析到 frps 服务器 IP。
2. **创建 Proxy Host**(NPM 后台 → `Hosts` → `Proxy Hosts` → `Add Proxy Host`):
   - Domain Names: `app.your-domain.com`
   - Scheme: `http`
   - Forward Hostname / IP: `127.0.0.1`(NPM 与 frps 同机时)
   - Forward Port: 与 `FRPS_VHOST_HTTP_PORT` Secret 一致(默认 `8080`)
3. **SSL**:勾选 `Request a new SSL Certificate` + `Force SSL`,同意 Let's Encrypt 条款,保存。
4. **验证**:浏览器访问 `https://app.your-domain.com`。

> 若 NPM 与 frps 不同机,Forward IP 填 frps 服务器内网 IP。

## ⬆️ Upgrade / 升级版本

### 服务端 frps

- **CI 升级**(推荐):`Actions` → `Deploy frps` → `Run workflow`,在 `version` 输入框填新版本号(如 `v0.71.0`),留空则仅重新部署当前版本不升级。
- **手动升级**:SSH 到服务器,`cd /app/frps && ./frps.sh update v0.71.0`

### 客户端 frpc

```bash
cd frpc
./frpc.sh update v0.71.0
```

脚本会自动修改 `docker-compose.yml` 中的镜像 tag 并重建容器。

## 🔧 Troubleshooting / 故障排查

| 现象 | 排查方向 |
|---|---|
| frpc 连不上 frps | 1. 检查 `auth.token` 两端是否一致;2. 检查 `serverAddr` / `serverPort`;3. 服务器防火墙是否放行 7000 端口;4. `./frpc.sh logs` 看错误 |
| 域名访问 502 Bad Gateway | 1. frps 容器是否运行(`./frps.sh status`);2. NPM 转发目标是否正确(应指向 `127.0.0.1:8080`);3. frpc 是否在线;4. 本地服务是否在 `localPort` 监听 |
| Dashboard(7500)打不开 | 1. 服务器防火墙放行 7500;2. `webServer.addr` 是否为 `0.0.0.0`;3. `./frps.sh status` 看容器状态 |
| `reload` 报错重载失败 | 需启用 `webServer` 段(frpc 是 admin UI),frps/frpc 均需开启才能热重载 |
| `./frps.sh status` 显示"容器未运行" | `./frps.sh start` 启动;若立即退出,`./frps.sh logs` 查看启动错误,常见为 toml 配置语法错误 |
| `envsubst: command not found` | 服务器未装 `gettext`,Debian/Ubuntu: `apt install -y gettext`;CentOS: `yum install -y gettext` |
| CI 部署 SSH 连接失败 | 1. `SSH_PRIVATE_KEY` 是否完整含 `BEGIN/END` 行;2. 公钥是否加入服务器 `~/.ssh/authorized_keys`;3. `SSH_PORT` 是否正确 |

## ⚠️ Notes / 注意事项

- **密钥安全**:`frps.toml` / `frpc.toml`(渲染后含密钥)已被 `.gitignore` 排除,切勿手动 `git add -f`。模板 `*.toml.tpl` 可安全入库。
- **envsubst 密码字符**:Dashboard / admin UI 密码请避免包含 `"` `$` `\` 字符,否则 `envsubst` 渲染会破坏 TOML 字符串语法或触发二次替换,导致 frp 启动失败。建议用字母数字 + `-_@#%^&` 等安全字符。
- **升级前备份**:`./frps.sh update` 会改写 `docker-compose.yml`,建议升级前 `cp docker-compose.yml docker-compose.yml.bak`。
- **Mac frpc 的 host.docker.internal**:这是 Docker Desktop 提供的固定名称,容器通过它访问 Mac 宿主机服务。Linux 上需用 `--add-host=host.docker.internal:host-gateway` 或改用宿主机内网 IP。
- **防火墙放行端口**:frps 服务器需放行 `7000`(frpc 连接)、`7500`(Dashboard)、`8080`(vhost HTTP)、`8443`(vhost HTTPS,如启用)。80/443 由 NPM 占用。
- **token 一致性**:frps 的 `FRPS_AUTH_TOKEN` 与 frpc 的 `auth.token` 必须**完全一致**,否则 frpc 无法连接。
- **frpc 不需要 CI**:frpc 跑在本地 Mac,改配置后渲染 `frpc.toml` 再 `./frpc.sh restart` 即可,无需走 GitHub Actions。
- **frpc admin UI 不暴露公网**:模板已移除把 7400 端口反代到公网的 `[[proxies]]`,admin UI 仅本地访问。如确需远程热重载,请用 SSH 隧道而非公网反代。
