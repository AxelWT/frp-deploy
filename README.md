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
- **P2P 直连(可选)** — `frpc-visitor` 子项目提供 xtcp 直连 + stcp 兜底,固定少数人桌面端可绕过云服务器直访 Mac

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
   │   │   └─────┬─────┘         └────────▲──────────┘   │     │
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

> 📌 此外项目还支持 **P2P 直连模式**(可选,见下方 [Part 3: P2P 直连](#part-3-p2p-直连可选-frpc-visitor-部署) 章节):固定少数人桌面端可通过 `frpc-visitor` 直连 Mac,xtcp 优先 + stcp 兜底,业务流量不经云服务器。

## 📁 Project Structure / 项目结构

```
frp-deploy/
├── frps/                              # 服务端(部署到云服务器)
│   ├── docker-compose.yml             # frps 容器定义,暴露 7000/7500/8080
│   ├── frps.toml.tpl                  # 配置模板,占位符 ${VAR} 由 CI 渲染
│   └── frps.sh                        # 管理脚本(start/stop/update/...)
├── frpc/                              # 客户端(部署到本地 Mac,被访问端)
│   ├── docker-compose.yml             # frpc 容器定义,暴露 7400(admin UI)
│   ├── frpc.toml.tpl                  # 客户端配置模板(含 HTTP 代理 + xtcp/stcp P2P 代理)
│   └── frpc.sh                        # 管理脚本
├── frpc-visitor/                      # P2P 访问端(可选,部署到固定访问者的 Mac/PC)
│   ├── docker-compose.yml             # visitor 容器定义,暴露 7400 + 各 visitor bindPort
│   ├── visitor.toml.tpl               # visitor 配置模板(xtcp 优先 + stcp fallback)
│   └── frpc-visitor.sh                # 管理脚本
├── pi-web/                            # pi-web 容器(可选,本地 Mac 跑 pi coding agent 的 Web UI)
│   ├── Dockerfile                     # 基于 node:22-alpine,npm install -g @axello/pi-web
│   ├── docker-compose.yml             # 容器定义,挂载 ~/.pi / ~/.pi-web / 项目目录,暴露 30141
│   └── pi-web.sh                      # 管理脚本(start/stop/restart/status/logs/update/clean)
├── .github/
│   └── workflows/
│       └── deploy-frps.yml            # frps 自动部署工作流
├── .gitignore                         # 排除渲染后的 frps.toml / frpc.toml / visitor.toml(含密钥)
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

### Part 3: P2P 直连(可选)/ frpc-visitor 部署

> 适用于**固定少数人桌面端**(Mac/PC/Linux)绕过云服务器直连 Mac 的场景。
> xtcp 直连优先,失败自动 fallback 到 stcp(经 frps 中转但端到端加密)。
> ⚠️ frp 无移动端 visitor,iOS/Android 不支持此方案,请用 HTTP 反代或 Tailscale。

#### 前置条件

1. **frps 服务器放行 `7000/tcp`** — frpc 连接必需。CI 已自动放行(ufw/iptables),手动部署需自行执行 `ufw allow 7000/tcp`。xtcp 是否需额外 UDP 端口待验证(见下文"验证 P2P 连通")
2. **被访问端 Mac 已部署 frpc** — 见 Part 2,且 `frpc.toml` 中已包含 `app1-p2p` / `app1-stcp` 等 P2P 代理段(模板已内置)
3. **访问端为 Mac/PC/Linux** — 需装 Docker(或 Docker Desktop)

#### 流量路径

```
                ┌──────────────────────────────┐
                │  云服务器 frps               │
                │  :7000/tcp 信令 + stcp 中转  │
                │  (业务流量仅在 stcp 兜底时经过)│
                └─────▲────────────────▲───────┘
                      │ 信令/打洞        │ 信令
                      │                 │
   ┌──────────────────┴─────┐ P2P 直连 ┌─┴─────────────────────┐
   │ Mac frpc (被访问端)    │◀─────────│ 访问端 frpc-visitor   │
   │ [[proxies]]            │  xtcp    │ [[visitors]]          │
   │  type=xtcp (app1-p2p)  │   ↓失败  │  type=xtcp            │
   │  type=stcp (app1-stcp) │ fallback │  fallbackTo=app1-stcp │
   │  local :2026           │─────────►│  bind 0.0.0.0:12026   │
   └────────────────────────┘  stcp中转 │  (compose 映射到      │
                                      │   宿主机 127.0.0.1)    │
                                      └───────────────────────┘
```

#### 部署步骤(在访问端机器上执行)

1. **克隆本仓库到访问端机器**(或仅 `rsync` 整个 `frpc-visitor/` 目录):

   ```bash
   git clone <your-repo-url> frp-deploy
   cd frp-deploy/frpc-visitor
   ```

2. **渲染 `visitor.toml`**(二选一):

   **方式 A:envsubst 渲染**

   ```bash
   cd frpc-visitor
   export FRPC_SERVER_ADDR="<frps 公网 IP>"          # 与被访问端 Mac frpc 一致
   export FRPC_AUTH_TOKEN="<frps auth.token>"        # 与 frps 的 FRPS_AUTH_TOKEN 一致
   export FRPC_ADMIN_USER="<admin-user>"             # 本机 admin UI 用户名
   export FRPC_ADMIN_PASSWORD="<admin-password>"     # 本机 admin UI 密码
   export FRPC_P2P_SECRET="<p2p-secret>"             # 与被访问端 Mac frpc 的 FRPC_P2P_SECRET 一致
   envsubst < visitor.toml.tpl > visitor.toml
   chmod 600 visitor.toml
   ```

   **方式 B:手动编辑**

   ```bash
   cd frpc-visitor
   cp visitor.toml.tpl visitor.toml
   # 用编辑器把 ${FRPC_SERVER_ADDR} 等占位符替换为真实值
   ```

   > 渲染后的 `visitor.toml` 含真实密钥,已被 `.gitignore` 排除。

3. **启动**:

   ```bash
   ./frpc-visitor.sh start
   ```

4. **验证 P2P 连通**:

   ```bash
   # 查看日志,确认 xtcp 是否打洞成功
   ./frpc-visitor.sh logs

   # 浏览器或 curl 访问本地 visitor bindPort
   curl http://127.0.0.1:12026     # app1(xtcp 优先,stcp 兜底)
   curl http://127.0.0.1:12028     # app2
   ```

   日志若出现 `xtcp connect success` 即直连成功;若出现 `fallback to stcp` 则走了 frps 中转兜底(仍可用,只是不直连)。

#### 与被访问端 Mac frpc 的对照关系

| 访问端 `visitor.toml` 字段 | 被访问端 `frpc.toml` 字段 | 说明 |
|---|---|---|
| `serverAddr` | `serverAddr` | 必须一致,都指向 frps |
| `auth.token` | `auth.token` | 必须一致 |
| `[[visitors]].serverName` | `[[proxies]].name` | visitor 的 `serverName` 对应被访问端 proxy 的 `name` |
| `[[visitors]].secretKey` | `[[proxies]].secretKey` | 必须一致,即 `FRPC_P2P_SECRET` |
| `[[visitors]].fallbackTo` | `[[proxies]].name` | 指向被访问端的 stcp proxy name |

#### 新增变量

| 变量 | 用途 | 分发渠道 |
|---|---|---|
| `FRPC_P2P_SECRET` | xtcp/stcp 握手密钥,独立于 `auth.token` | Mac 端 envsubst + 访问端 envsubst;通过 1Password / 加密 IM 分发给固定用户,不入 git |

### Part 4: pi-web(可选)/ 本地 Web UI 容器

> 在本地 Mac 用容器跑 [`@axello/pi-web`](https://www.npmjs.com/package/@axello/pi-web)(pi coding agent 的 Web UI),
> 挂载 `~/.pi` / `~/.pi-web` 及项目目录,浏览器访问 `http://127.0.0.1:30141` 即可。
> 与 frp 体系相互独立,仅供本机使用,不涉及公网流量。

#### 前置条件

- 已装 Docker Desktop(Mac)
- Node 由容器提供(`node:22-alpine`,满足 pi-web 要求的 `>=22.19.0`),宿主机无需预装 Node

#### 部署步骤

1. **启动**(首次会拉 `node:22-alpine` 并 `npm install -g @axello/pi-web`,稍慢):

   ```bash
   cd pi-web
   ./pi-web.sh start
   ```

2. **验证**:浏览器访问 `http://127.0.0.1:30141`,或 `curl -I http://127.0.0.1:30141`。

3. **查看日志 / 状态**:

   ```bash
   ./pi-web.sh logs
   ./pi-web.sh status
   ```

#### 挂载说明

| 宿主机路径 | 容器路径 | 权限 | 用途 |
|---|---|---|---|
| `~/.pi` | `/root/.pi` | rw | pi-agent 会话数据 |
| `~/.pi-web` | `/root/.pi-web` | rw | pi-web 运行时(detach PID/日志等) |
| `~/PycharmProjects` | `/root/PycharmProjects` | rw | 项目代码(coding agent 读写) |
| `~/Documents` | `/root/Documents` | rw | 文档工作区 |

> 项目目录若只希望 pi-web 只读访问,把 `docker-compose.yml` 里对应行的 `:rw` 改 `:ro`。
> 挂载路径在 `docker-compose.yml` 中用 `${HOME}` 表达,Docker Compose 自动解析为宿主机家目录,无需额外渲染。

#### 升级 pi-web 版本

```bash
cd pi-web
./pi-web.sh update 0.11.0      # 脚本会改 compose 并重建镜像
```

#### 与其他组件的关系

- **端口独立**:pi-web 用 `127.0.0.1:30141`,与 frps/frpc/frpc-visitor 的端口无冲突,可同机共存
- **配置无密钥**:pi-web 目录全为模板文件,无渲染产物,直接入库安全
- **不参与 CI/CD**:仅本机运行,无需 GitHub Actions

## ⚙️ Configuration Reference / 配置详解

### `frps.toml.tpl` 关键字段

| 字段 | 默认值 | 说明 |
|---|---|---|
| `bindAddr` | `0.0.0.0` | 监听地址,公网服务保持 0.0.0.0 |
| `bindPort` | `7000` | frpc 连接端口,客户端 `serverPort` 必须一致 |
| `vhostHTTPPort` | `${FRPS_VHOST_HTTP_PORT}` | HTTP 代理流量入口,由 Secret 渲染(默认 8080) |
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
| `[[proxies]].type` | `xtcp` / `stcp` | P2P 直连:xtcp 打洞直连,stcp 经 frps 中转兜底(成对配置,见 Part 3) |
| `[[proxies]].secretKey` | `${FRPC_P2P_SECRET}` | xtcp/stcp 握手密钥,与 visitor 端必须一致 |

### `visitor.toml.tpl` 关键字段

| 字段 | 示例 | 说明 |
|---|---|---|
| `serverAddr` | `${FRPC_SERVER_ADDR}` | 与被访问端 frpc 一致,指向同一台 frps |
| `serverPort` | `7000` | 对应 frps 的 `bindPort` |
| `auth.token` | `${FRPC_AUTH_TOKEN}` | 与 frps / frpc 的 `auth.token` 一致 |
| `webServer.port` | `7400` | visitor admin UI,用于热重载,仅本地访问 |
| `[[visitors]].type` | `xtcp` | xtcp 直连,失败自动 fallback 到 stcp(由 `fallbackTo` 指定) |
| `[[visitors]].serverName` | `app1-p2p` | 对应被访问端 frpc `[[proxies]].name`,必须完全一致 |
| `[[visitors]].secretKey` | `${FRPC_P2P_SECRET}` | 与被访问端对应 proxy 的 `secretKey` 一致 |
| `[[visitors]].bindAddr` | `0.0.0.0` | 容器内必须绑 0.0.0.0 才能被 docker 转发命中;"仅本机访问"由 compose 的 `127.0.0.1:` 前缀实现 |
| `[[visitors]].bindPort` | `12026` | 访问端本地监听端口,浏览器访问 `127.0.0.1:<bindPort>` |
| `[[visitors]].fallbackTo` | `app1-stcp` | xtcp 失败时回退到的 stcp proxy name(被访问端 frpc 需配置对应 stcp proxy) |
| `[[visitors]].fallbackTimeoutMs` | `4000` | xtcp 连接超时阈值,超时触发 fallback(留足 NAT 打洞时间) |

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
> frpc-visitor 同理,在 `frpc-visitor/` 目录下执行 `./frpc-visitor.sh start`。

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

### 客户端 frpc-visitor

```bash
cd frpc-visitor
./frpc-visitor.sh update v0.71.0
```

脚本会自动修改 `docker-compose.yml` 中的镜像 tag 并重建容器。

> ⚠️ **版本同步**:frps / frpc / frpc-visitor 三端的镜像版本需保持一致,避免协议不兼容。升级时分别执行三个 `update` 脚本(或 CI 升级 frps 后,Mac 端和访问端各跑一次对应脚本)。

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
| xtcp 总是 fallback 到 stcp | 1. 任一端是否在对称 NAT 后(几乎必失败,属正常);2. Docker Desktop 容器打洞成功率本身较低,可改宿主机 binary 直跑;3. frps 是否需额外 UDP 端口供 xtcp 协调待验证(可跑 `docker run --rm ghcr.io/fatedier/frps:v0.70.0 --help 2>&1 \| grep -i -E 'udp\|xtcp'` 核实) |
| visitor 启动报 `bind: address already in use` | 修改 `visitor.toml` 中对应 visitor 的 `bindPort`(默认 12026 / 12028),并在 `docker-compose.yml` 的 `ports` 同步修改 |
| visitor 连不上(超时) | 1. `serverName` 是否与被访问端 `[[proxies]].name` 完全一致;2. `secretKey`(`FRPC_P2P_SECRET`)两端是否一致;3. 被访问端 frpc 是否在线(`./frpc.sh status`);4. frps 是否可达 |
| visitor 日志无 `fallback to stcp` 也连不通 | 1. `fallbackTo` 指向的 stcp proxy name 是否正确;2. 被访问端是否同时配置了 xtcp + stcp 两段 proxy |

## ⚠️ Notes / 注意事项

- **密钥安全**:`frps.toml` / `frpc.toml` / `visitor.toml`(渲染后含密钥)已被 `.gitignore` 排除,切勿手动 `git add -f`。模板 `*.toml.tpl` 可安全入库。
- **envsubst 密码字符**:Dashboard / admin UI 密码请避免包含 `"` `$` `\` 字符,否则 `envsubst` 渲染会破坏 TOML 字符串语法或触发二次替换,导致 frp 启动失败。建议用字母数字 + `-_@#%^&` 等安全字符。`FRPC_P2P_SECRET` 同理。
- **升级前备份**:`./frps.sh update` 会改写 `docker-compose.yml`,建议升级前 `cp docker-compose.yml docker-compose.yml.bak`。
- **Mac frpc 的 host.docker.internal**:这是 Docker Desktop 提供的固定名称,容器通过它访问 Mac 宿主机服务。Linux 上需用 `--add-host=host.docker.internal:host-gateway` 或改用宿主机内网 IP。
- **防火墙放行端口**:frps 服务器需放行 `7000/tcp`(frpc 连接)、`7500`(Dashboard)、`8080`(vhost HTTP)。80/443 由 NPM 占用。CI 顺带放行 `7000/udp` 作为防御性规则(幂等无害),若将来确认 xtcp 需要 frps 监听 UDP 端口可复用。
- **xtcp 与 frps UDP 监听**:此前曾误加 `bindUDPPort` 字段导致 frps 启动失败(`json: unknown field "bindUDPPort"`,v0.70.0 不识别),已移除。xtcp 是否需要 frps 端额外 UDP 监听待实测验证:若 visitor 日志显示 `xtcp connect success` 则无需;若总 fallback 到 stcp,需查官方文档确认正确字段名再加回。
- **token 一致性**:frps 的 `FRPS_AUTH_TOKEN` 与 frpc / frpc-visitor 的 `auth.token` 必须**完全一致**,否则 frpc 无法连接。
- **P2P secretKey 一致性**:被访问端 `frpc.toml` 与访问端 `visitor.toml` 中,对应同一服务的 `secretKey`(即 `FRPC_P2P_SECRET`)必须**完全一致**;`serverName` 必须对应被访问端 `[[proxies]].name`。
- **Docker Desktop 打洞成功率**:frpc/frpc-visitor 在 Docker 容器内运行,UDP 经 Docker NAT 转发会降低 xtcp 打洞成功率。若发现 xtcp 几乎总走 fallback,可改用宿主机 binary 直跑 frpc(本仓库不提供该模式,需自行处理)。
- **对称型 NAT**:任一端在对称 NAT 后,xtcp 几乎必失败,自动 fallback 到 stcp(经 frps 中转,但端到端加密,可用性有保障)。
- **P2P 仅限桌面端**:frp 无官方移动端 visitor,iOS/Android 无法使用 P2P 方案,移动端请走 HTTP 反代或自行叠加 Tailscale。
- **frpc 不需要 CI**:frpc 跑在本地 Mac,改配置后渲染 `frpc.toml` 再 `./frpc.sh restart` 即可,无需走 GitHub Actions。frpc-visitor 同理。
- **frpc 与 frpc-visitor 不要同机运行**:两者默认都映射 `7400` 端口(admin UI),同机会冲突。若必须同机,改 `frpc-visitor/visitor.toml.tpl` 的 `webServer.port` 与 `docker-compose.yml` 的对应端口映射(如改为 7401)。
- **frpc admin UI 不暴露公网**:模板已移除把 7400 端口反代到公网的 `[[proxies]]`,admin UI 仅本地访问。如确需远程热重载,请用 SSH 隧道而非公网反代。frpc-visitor 的端口映射已加 `127.0.0.1:` 前缀,LAN 不可达。
