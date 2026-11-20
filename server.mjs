// MYNOTE 私密笔记 - Docker 版启动器
//
// 用 Miniflare (Cloudflare Workers 的本地运行时) 跑 worker.js,
// D1 数据库用本地 SQLite 文件, 持久化到 DATA_DIR。
// 不用 Cloudflare 账号, 一台有 Docker 的机器就能跑。

import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Miniflare } from "miniflare";

const PORT = Number(process.env.PORT || 8787);
const HOST = process.env.HOST || "0.0.0.0";
const DATA_DIR = process.env.DATA_DIR || "/app/data";
const dir = path.dirname(fileURLToPath(import.meta.url));

const mf = new Miniflare({
  scriptPath: path.join(dir, "worker.js"),
  modules: true,
  compatibilityDate: "2024-01-01",
  d1Databases: ["NOTES_DB"],
  d1Persist: DATA_DIR,
  bindings: {
    NOTES_PASSWORD: process.env.NOTES_PASSWORD || "admin",
    NOTES_API_KEY: process.env.NOTES_API_KEY || "admin",
    NOTES_SESSION_SECRET: process.env.NOTES_SESSION_SECRET || "admin",
  },
});

await mf.ready;
console.log(`[mynote] worker ready, D1 data in ${DATA_DIR}`);

const server = http.createServer(async (req, res) => {
  try {
    const url = `http://127.0.0.1:${PORT}${req.url}`;
    const headers = new Headers();
    for (const [name, value] of Object.entries(req.headers)) {
      if (value === undefined) continue;
      // host / content-length / transfer-encoding 由 Request 按 url 与 body 自己算
      if (name === "host" || name === "content-length" || name === "transfer-encoding" || name === "connection") continue;
      headers.set(name, Array.isArray(value) ? value.join(", ") : value);
    }
    let body;
    if (req.method !== "GET" && req.method !== "HEAD") {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      if (chunks.length) body = Buffer.concat(chunks);
    }
    // dispatchFetch 要的是 (url 字符串, init), 直接传 Request 对象会被它
    // 当成 URL 字符串拼成 "[object Request]" 而报错, 所以只传 url + init。
    const init = { method: req.method, headers };
    if (body !== undefined) init.body = body;
    const response = await mf.dispatchFetch(url, init);

    const out = {};
    response.headers.forEach((v, k) => { if (k !== "set-cookie") out[k] = v; });
    const setCookie = response.headers.getSetCookie();
    if (setCookie.length) out["set-cookie"] = setCookie;

    const buf = Buffer.from(await response.arrayBuffer());
    res.writeHead(response.status, out);
    res.end(buf);
  } catch (err) {
    console.error("[mynote] request failed:", err);
    if (!res.headersSent) res.writeHead(500, { "content-type": "text/plain; charset=utf-8" });
    res.end("internal error");
  }
});

server.listen(PORT, HOST, () => {
  console.log(`[mynote] listening on http://${HOST}:${PORT} (打开 http://localhost:${PORT})`);
});

function shutdown(signal) {
  console.log(`[mynote] ${signal}, shutting down...`);
  server.close(async () => {
    await mf.dispose();
    process.exit(0);
  });
  setTimeout(() => process.exit(0), 5000).unref();
}
process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
