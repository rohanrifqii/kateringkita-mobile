// Demo aplikasi (Flutter web) di HP lewat WiFi yang sama dengan laptop.
//
//   node tool/demo_wifi.mjs           -> sajikan build/web (build dulu bila belum ada)
//   node tool/demo_wifi.mjs --build   -> build ulang dulu, lalu sajikan
//
// Build memakai API_BASE_URL=/api/v1 (relatif): aplikasi memanggil API ke alamat yang sedang
// dibuka di HP, jadi build yang sama tetap jalan walau IP WiFi laptop berubah. Server ini
// meneruskan /api/ ke backend production dan /img/ ke penyimpanan foto, dari SATU origin
// (tanpa masalah CORS). Pengaturan production tidak diubah.
import { spawnSync } from "node:child_process";
import { createReadStream, existsSync, statSync } from "node:fs";
import http from "node:http";
import https from "node:https";
import { networkInterfaces } from "node:os";
import { dirname, extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const REPO = dirname(dirname(fileURLToPath(import.meta.url)));
const ROOT = join(REPO, "build", "web");
const TARGET = "ketring-45f82aef1ca0.herokuapp.com";
const IMG_HOST = "img.edufin.app";
const PORT = Number(process.env.PORT ?? 8080);
const TYPES = { ".html": "text/html", ".js": "text/javascript", ".mjs": "text/javascript", ".json": "application/json", ".wasm": "application/wasm", ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml", ".ttf": "font/ttf", ".otf": "font/otf", ".css": "text/css", ".ico": "image/x-icon" };

if (process.argv.includes("--build") || !existsSync(join(ROOT, "index.html"))) {
  console.log("Build Flutter web (beberapa menit)...");
  const r = spawnSync("flutter", ["build", "web", "--release", "--dart-define=API_BASE_URL=/api/v1"], { cwd: REPO, stdio: "inherit", shell: true });
  if (r.status !== 0) process.exit(r.status ?? 1);
}

const jam = () => new Date().toISOString().slice(11, 19);

http.createServer((req, res) => {
  // Foto (R2) tanpa header CORS, padahal Flutter web wajib CORS untuk Image.network:
  // URL foto di respons API ditulis ulang ke /img/ di origin ini, lalu /img/ diteruskan.
  if (req.url.startsWith("/img/")) {
    const up = https.request({ host: IMG_HOST, path: req.url.slice(4), method: req.method, headers: { accept: req.headers.accept ?? "*/*" } }, (r) => {
      res.writeHead(r.statusCode ?? 502, r.headers);
      r.pipe(res);
    });
    up.on("error", () => { res.writeHead(502); res.end(); });
    return up.end();
  }
  if (req.url.startsWith("/api/")) {
    const headers = { ...req.headers, host: TARGET, "accept-encoding": "identity" };
    delete headers.origin; delete headers.referer;
    // tanpa ini browser dapat 304 lalu memakai body lama (URL foto belum ditulis ulang)
    delete headers["if-none-match"]; delete headers["if-modified-since"];
    const up = https.request({ host: TARGET, path: req.url, method: req.method, headers }, (r) => {
      console.log(jam(), req.socket.remoteAddress, req.method, req.url.split("?")[0], "->", r.statusCode);
      if (!String(r.headers["content-type"] ?? "").includes("json")) {
        res.writeHead(r.statusCode ?? 502, r.headers);
        return r.pipe(res);
      }
      const chunks = [];
      r.on("data", (c) => chunks.push(c)).on("end", () => {
        const body = Buffer.concat(chunks).toString("utf8").replaceAll(`https://${IMG_HOST}/`, `http://${req.headers.host}/img/`);
        const h = { ...r.headers };
        delete h["content-length"]; delete h["content-encoding"]; delete h.etag; delete h["last-modified"];
        h["cache-control"] = "no-store";
        res.writeHead(r.statusCode ?? 502, h);
        res.end(body);
      });
    });
    up.on("error", (e) => { res.writeHead(502, { "Content-Type": "application/json" }); res.end(JSON.stringify({ error: { code: "PROXY", message: e.message } })); });
    return req.pipe(up);
  }
  const p = normalize(decodeURIComponent(new URL(req.url, "http://x").pathname)).replace(/^([\\/])+/, "");
  let file = join(ROOT, p || "index.html");
  try { if (statSync(file).isDirectory()) file = join(file, "index.html"); } catch { file = join(ROOT, "index.html"); }
  res.writeHead(200, { "Content-Type": TYPES[extname(file)] ?? "application/octet-stream", "Cache-Control": "no-store" });
  createReadStream(file).on("error", () => res.end()).pipe(res);
}).listen(PORT, "0.0.0.0", () => {
  const ip = Object.values(networkInterfaces()).flat().filter((a) => a && a.family === "IPv4" && !a.internal && !a.address.startsWith("169.254."));
  console.log(`\nAplikasi siap. /api/ -> https://${TARGET}`);
  console.log("Buka di HP (WiFi yang sama):");
  for (const a of ip) console.log(`  http://${a.address}:${PORT}`);
  console.log("Tidak terbuka di HP? Izinkan Node.js di Windows Firewall, atau pakai hotspot HP.\n");
});
