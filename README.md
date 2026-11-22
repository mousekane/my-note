# MYNOTE 私密笔记

一个人的私人笔记。全部私密，没有账号注册，没有公开链接，不登录什么都看不到。手机可以装到主屏幕，跟 App 一样用。

- 文字为主，也可以插图片（自动压缩，单张 800KB 以内）
- 分类、标签、置顶、草稿、回收站、备份导出/导入、夜间模式
- 登录密码和 API 密钥是同一串，改密码两边一起变

## 两种部署方式，选一个就行

| | Cloudflare 部署 | Docker 部署 |
| --- | --- | --- |
| 适合 | 不想管服务器，免费额度就够 | 有自己的机器（电脑、树莓派、NAS、R2S、VPS），想把数据放自己手里 |
| 要什么 | 一个 Cloudflare 账号（免费） | 一台装了 Docker 的机器 |
| 花钱 | 不用，免费额度够用 | 不用，机器是自己的 |
| 数据在哪 | Cloudflare D1 数据库 | 机器上的一个 Docker 数据卷 |
| 地址 | `https://notes.<你的子域名>.workers.dev`，或绑自己的域名 | `http://本机IP:8787`（局域网），或自己配反代上公网 |

两种方式跑的是同一份 `worker.js`，功能一模一样，数据不互通（各存各的）。下面先写 Docker，再写 Cloudflare。

---

## 方式一：Docker 一键安装（推荐）

在一台装了 Docker 的机器上跑下面这一行就行。没装 Docker 的话，Debian / Ubuntu / 树莓派系统会自动帮你装上。

```bash
curl -fsSL https://raw.githubusercontent.com/mousekane/my-note/main/install.sh | bash
```

装完打开 `http://本机IP:8787`，密码 `admin` 登录。**登录后立刻改密码**：点右上角三条杠进设置 → 修改密码，输新密码保存。改完登录密码和 API 密钥一起变，旧的 admin 立刻失效。

容器用主机网络直接跑（`--network host`），不做端口映射：OpenWrt 的防火墙默认会拦 Docker 桥接端口转发，主机网络才能装完直接打开。数据仍存在 `mynote-data` 卷里（挂载到 `/app/data`），删容器也不会丢。

想换端口或密码再装：

```bash
MYNOTE_PORT=8080 MYNOTE_PASSWORD=你的密码 bash install.sh
```

装到手机主屏幕：安卓 Chrome 打开网站 → 菜单 → 添加到主屏幕；苹果 Safari 打开 → 分享 → 添加到主屏幕。

### 常用命令

```bash
docker logs -f mynote     # 看日志
docker stop mynote        # 停止
docker start mynote       # 再启动
docker rm -f mynote       # 删容器（数据在卷里，不会丢）
docker volume inspect mynote-data   # 数据卷在主机上的位置
```

### 更新

重新跑一遍安装脚本就行（数据在卷里，更新不会丢笔记）：

```bash
bash install.sh
```

### 兜底：镜像实在拉不到，用离线 tar 包

如果上面两个镜像地址都拉不到（比如网络把 registry 协议也挡了），可以用离线镜像包：每次打版本标签（`v*`，比如 `v1.0.0`）都会自动把镜像导出成 tar 包挂到 Release 上，`mynote-linux-amd64.tar`（x86）和 `mynote-linux-arm64.tar`（树莓派 / R2S）各一个，下载后 `docker load` 导入再装，不用联网拉镜像。

```bash
# 以 arm64（树莓派 / R2S）为例：先下载 tar 包
curl -fsSL -o mynote-linux-arm64.tar \
  https://github.com/mousekane/my-note/releases/download/v1.0.0/mynote-linux-arm64.tar
# 再用 tar 包安装（不再联网拉镜像）
curl -fsSL https://raw.githubusercontent.com/mousekane/my-note/main/install.sh -o install.sh
MYNOTE_TAR=./mynote-linux-arm64.tar bash install.sh
```

注意：`v1.0.0` 换成仓库 Releases 页面上实际有的最新版本号；tar 包是随版本 Release 自动生成的，没有新版本就没有新 tar 包，旧版本用旧 tar 包一样能跑。x86 机器把上面两处 `arm64` 换成 `amd64` 即可。

---

## 方式二：Docker 手动部署（下源码自己跑）

适合想自己改代码、或本地构建镜像的人。

### 拉预构建镜像跑（不用编译）

```bash
git clone https://github.com/mousekane/my-note.git
cd my-note
docker compose up -d
```

打开 `http://localhost:8787`，密码 `admin`。

### 本地构建镜像跑

```bash
git clone https://github.com/mousekane/my-note.git
cd my-note
docker compose up -d --build
```

要先把 `docker-compose.yml` 里的 `image:` 一行换成 `build: .`（文件里有注释）。

### 直接构建镜像

```bash
docker build -t mynote:latest .
docker run -d --name mynote --restart unless-stopped \
  --network host -v mynote-data:/app/data \
  -e NOTES_PASSWORD=admin -e NOTES_API_KEY=admin -e NOTES_SESSION_SECRET=admin \
  mynote:latest
```

### 多架构

x86 和 ARM 都支持：x86 电脑、树莓派、R2S、群晖 / 威联通（ARM 机型）都能跑。`docker compose up -d` 是在本地构建，两种架构都能直接跑；GitHub Actions 每次推代码也会自动打出 `linux/amd64` + `linux/arm64` 两个架构的镜像推到 `ghcr.io/mousekane/my-note:latest`，一键安装脚本拉的就是这个。

想自己一次打出两个架构：

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t mynote:latest .
```

### 配置

| 想改什么 | 怎么做 |
| --- | --- |
| 登录密码 / API 密钥 | 把 `.env.example` 复制成 `.env` 再改里面的值，然后 `docker compose up -d` 重启；或改 `docker-compose.yml` 里的 `environment`；一键安装脚本用 `MYNOTE_PASSWORD=... bash install.sh` |
| 端口（默认 8787） | 容器用主机网络，直接占主机的端口：一键安装脚本用 `MYNOTE_PORT=8080`；compose 部署改 `docker-compose.yml` 里 environment 的 `PORT` |
| 数据放哪 | 默认存在 Docker 的 `mynote-data` 卷里。想放指定目录，把 `volumes` 里的 `- mynote-data:/app/data` 改成 `- /你的目录:/app/data` |

不改配置也能直接用：密码和 API 密钥默认都是 `admin`。

密码忘了怎么办：

- 没在设置页改过密码：改 `.env` 或 `docker-compose.yml` 里的 `NOTES_PASSWORD`，重启容器就行
- 在设置页改过密码后忘了：进容器删掉 D1 里的密码记录就恢复成环境变量里的密码（没设就是 admin）：
  ```bash
  docker exec mynote sqlite3 /app/data/*.sqlite "DELETE FROM settings WHERE key = 'password_hash';"
  ```
  （如果没有 sqlite3 命令行，用 `docker compose down` 后删掉卷重建也行，但笔记会一起没了，先导出备份）

---

## 方式三：Cloudflare 部署（网页操作，不用命令行，约 10 分钟）

### 准备

1. 一个 Cloudflare 账号（免费注册，https://dash.cloudflare.com/sign-up）
2. 域名（可选）：有自己的域名可以绑 `notes.你的域名`；没有也能用 Cloudflare 送的 `https://notes.<你的子域名>.workers.dev` 地址，一样能用

### 第 1 步：建 D1 数据库

1. 进 Cloudflare 控制台，左侧找到 **Storage & databases → D1**（名字可能叫 D1 SQL Database）
2. 点 **Create database**，名字填 `notes-db`，点 Create
3. 记下这个库，以后笔记和图片都存在这里

### 第 2 步：建 Worker，粘贴代码

1. 左侧 **Workers & Pages → Create → Worker**，名字填 `notes`，点 Deploy
2. 点 **Edit code**（编辑代码），把本仓库里 `worker.js` 的全部内容复制粘贴进去，替换掉原来的示例代码
3. 点右上角 **Deploy**（部署）。看到部署成功就行

### 第 3 步：把 D1 绑到 Worker 上（关键一步，漏了会打不开）

1. 进这个 Worker，点 **Settings → Variables**
2. 找到 **D1 database bindings**，点 **Add binding**
3. Variable name 填 `NOTES_DB`（必须一模一样，大写）
4. D1 database 下拉选刚才建的 `notes-db`，保存
5. 回到 Worker 页面再点一次 **Deploy**，让绑定生效

### 第 4 步：打开网站，登录

1. Worker 页面上方会显示地址，形如 `https://notes.<你的子域名>.workers.dev`，点开
2. 第一次打开会自动建表，稍等几秒再刷新一次
3. 登录页输入密码：`admin`
4. **登录后立刻改密码**：点右上角三条杠进设置 → 修改密码，输新密码保存。改完登录密码和 API 密钥一起变，旧的 admin 立刻失效

### 第 5 步（可选）：绑自己的域名

Worker → **Settings → Domains → Add custom domain**，填 `notes.你的域名`，按提示去你的域名 DNS 里加一条 CNAME 记录。没有域名就跳过这步，直接用 workers.dev 的地址。

### 第 6 步（可选）：导入两条示例笔记

登录后进设置 → 备份 → 导入备份，选本仓库里的 `示例笔记.json`，会多出两条示例笔记（一条欢迎词、一条示例），看完可以删掉。不想导入就跳过。

### 第 7 步：装到手机主屏幕

- 安卓 Chrome 打开网站 → 右上角菜单 → 添加到主屏幕
- 苹果 Safari 打开网站 → 分享按钮 → 添加到主屏幕

以后点主屏幕图标直接进，跟 App 一样，全屏，没有浏览器框。

### 命令行部署（适合会用 wrangler 的人）

```bash
npx wrangler d1 create notes-db
# 把返回的 database_id 填到 wrangler.toml 里
npx wrangler deploy
```

---

## 日常使用（两种部署方式都一样）

- 写笔记：点右下角 ＋，写完点「发布」才会出现在首页；没发布之前是草稿，在设置 → 草稿里找
- 左滑一条笔记：编辑、置顶、删除（删除先去回收站，30 天内可恢复）
- 分类：设置 → 分类里添加，写文章时选；点首页标题 MYNOTE 可以按分类看
- 夜间模式：页眉月亮按钮，点一下切换，再点回来
- 退出登录：设置 → 退出登录（红色按钮），退了下次打开要重新输密码
- 备份：设置 → 备份 → 导出备份（下载一个压缩包）；导入备份按 id 恢复，重复的直接覆盖
- API：登录后用同一个密码当 Bearer Token 调 `/api/v1/*`，也可以走 MCP（`/mcp`，共 14 个工具）

## 它是怎么跑的

全部代码就一个 `worker.js`：接口 + 网页 + PWA + MCP 都在里面。Cloudflare 版直接跑在 Worker 上，D1 就是数据库。Docker 版靠 Miniflare（Cloudflare Workers 的本地运行时）跑同一份 `worker.js`，D1 换成本地 SQLite 文件存在 `/app/data` 里，`server.mjs` 是个很小的 Node 启动器，只负责把 HTTP 请求转给 Worker。默认密码和 API 密钥都是 `admin`；登录 Cookie 的 `Secure` 属性只在 HTTPS 访问时才加（Docker 常走明文 HTTP，加了 `Secure` 浏览器就不回传 Cookie，会登录完立刻掉线）。通过域名 + 反代走 HTTPS 访问时（反代透传 X-Forwarded-Proto），http 请求会 301 跳到 https；局域网直接用 http://本机IP:8787 不受影响。

## 常见问题

- **端口被占用**：一键安装时设 `MYNOTE_PORT=8080`；compose 部署改 `docker-compose.yml` 里 environment 的 `PORT`（容器用主机网络，直接占主机的端口）
- **打开一直让登录，登录完又弹回登录页**：关掉重开一次；还不行就清掉这个网站的缓存数据再进
- **改了代码，手机上没变化**：手机关掉重开一次（Service Worker 缓存，要拉新版）
- **容器启动后马上退出**：跑 `docker logs mynote` 看报错，常见是 8787 端口被占或 `/app/data` 写不进去
- **Cloudflare 部署后打不开**：先检查第 3 步 D1 绑定有没有做，Variable name 必须是 `NOTES_DB`

## 文件清单

| 文件 | 说明 |
| --- | --- |
| `worker.js` | 全部代码，单文件：接口 + 网页 + PWA + MCP（Cloudflare 与 Docker 共用） |
| `wrangler.toml` | Cloudflare 部署配置（D1 绑定） |
| `install.sh` | Docker 一键安装脚本 |
| `Dockerfile` | 构建镜像：node:20-slim + miniflare（多架构） |
| `docker-compose.yml` | Docker 一键启动：拉预构建镜像、主机网络、环境变量、数据卷 |
| `server.mjs` | Docker 启动器：把 HTTP 请求转给 Worker |
| `package.json` / `package-lock.json` | 只依赖 miniflare 一个包 |
| `.env.example` | 环境变量示例，复制成 `.env` 再改 |
| `.github/workflows/docker.yml` | 每次推 main 自动构建 amd64 + arm64 镜像推到 GHCR |
| `assets/` | PWA 图标 |
| `示例笔记.json` | 两条示例笔记，导入用 |
| `README.md` | 就是这份指南 |
