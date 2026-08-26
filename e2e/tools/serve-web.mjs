// Static server for the built Flutter web bundle.
//
// This exists instead of a `serve`/`http-server` dependency because the one
// rule that matters here is not a flag on somebody else's CLI: any host the
// Trainer Console is deployed to **must rewrite unknown paths to
// /index.html**, or a refresh on a deep link 404s (see CLAUDE.md, "Web
// support"). Keeping that rule as executable code means the E2E run exercises
// the same contract production hosting has to honour.
//
// Usage: node tools/serve-web.mjs [--root <dir>] [--port <n>]

import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { join, normalize, extname, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const args = process.argv.slice(2);
const argOf = (name, fallback) => {
  const i = args.indexOf(name);
  return i === -1 ? fallback : args[i + 1];
};

// The default is resolved against this file, not the shell's cwd, so the
// server finds the bundle whether it is started by Playwright, by npm, or by
// hand from the repo root. An explicit --root is the caller's own path and is
// resolved normally.
const here = dirname(fileURLToPath(import.meta.url));
const rootArg = argOf('--root', null);
const root = rootArg ? resolve(rootArg) : resolve(here, '../../fittnes_tracker/build/web');
const port = Number(argOf('--port', process.env.PORT ?? '4173'));

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.bin': 'application/octet-stream',
  '.map': 'application/json; charset=utf-8',
};

/** Resolve a URL path to a file inside `root`, or null if it escapes / is missing. */
async function resolveFile(urlPath) {
  // normalize() collapses `..` before the join, so a crafted path cannot climb
  // out of the bundle directory.
  const candidate = join(root, normalize(urlPath).replace(/^(\.\.[/\\])+/, ''));
  if (!candidate.startsWith(root)) return null;
  try {
    const info = await stat(candidate);
    if (info.isDirectory()) return resolveFile(join(urlPath, 'index.html'));
    return candidate;
  } catch {
    return null;
  }
}

const server = createServer(async (req, res) => {
  const urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  let file = await resolveFile(urlPath);

  // The SPA rewrite. Only paths that look like routes fall back to the shell —
  // a missing asset must stay a 404, otherwise a typo'd font URL silently
  // serves HTML and the failure surfaces somewhere far away.
  if (!file && extname(urlPath) === '') file = await resolveFile('/index.html');

  if (!file) {
    res.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
    res.end('Not found');
    return;
  }

  res.writeHead(200, {
    'content-type': MIME[extname(file).toLowerCase()] ?? 'application/octet-stream',
    // CanvasKit/skwasm are fetched with these set; without them the engine
    // refuses to start under a cross-origin-isolated context.
    'cross-origin-opener-policy': 'same-origin',
    'cross-origin-embedder-policy': 'credentialless',
    'cache-control': 'no-store',
  });
  createReadStream(file).pipe(res);
});

try {
  await stat(join(root, 'index.html'));
} catch {
  console.error(
    `No Flutter web bundle at ${root}\n` +
      `Build it first:\n` +
      `  cd fittnes_tracker && flutter build web --release`,
  );
  process.exit(1);
}

server.listen(port, () => console.log(`Serving ${root} on http://localhost:${port}`));
