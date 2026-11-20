# MYNOTE 私密笔记 - Docker 版
#
# 多架构: 基础镜像 node:20-slim 本身支持 linux/amd64 与 linux/arm64,
# miniflare 自带的 workerd 二进制也是按平台安装的, 所以同一份 Dockerfile
# 在 x86 与 ARM (树莓派、R2S、群晖 ARM 机型等) 上都能直接构建运行。
# 想一次打出两个架构的镜像: docker buildx build --platform linux/amd64,linux/arm64 -t mynote:latest .
FROM node:20-slim

WORKDIR /app

# 只装运行时依赖 (miniflare), 用 npm ci 保证每次构建的版本一致
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY worker.js server.mjs ./

# D1 数据 (SQLite 文件) 存在这里, 用 volume 持久化, 删容器也不会丢
VOLUME ["/app/data"]
EXPOSE 8787

ENV PORT=8787
ENV DATA_DIR=/app/data
# 不填密码就是 admin (worker.js 里有默认回退); 改密码在 docker-compose.yml 或 .env 里设
ENV NOTES_PASSWORD=admin
ENV NOTES_API_KEY=admin
ENV NOTES_SESSION_SECRET=admin

CMD ["node", "server.mjs"]
