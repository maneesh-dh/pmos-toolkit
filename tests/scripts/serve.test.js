'use strict';
// Regression tests for assets/serve.js — path-traversal + MIME map.
// Run via: bash tests/scripts/assert_serve_js_unit.sh

const path = require('path');
const fs   = require('fs');
const http = require('http');

const REPO = path.resolve(__dirname, '..', '..');
const SERVE_PATH = path.join(REPO, 'plugins/pmos-toolkit/skills/_shared/html-authoring/assets/serve.js');
const { start } = require(SERVE_PATH);

let passed = 0, failed = 0;
function test(name, fn) {
  return Promise.resolve()
    .then(() => fn())
    .then(() => { console.log(`  ok  ${name}`); passed++; })
    .catch((e) => { console.log(`  FAIL ${name}\n       ${e.stack || e.message}`); failed++; });
}
function assert(cond, msg) { if (!cond) throw new Error(msg); }

function get(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, body: Buffer.concat(chunks).toString('utf8'), headers: res.headers }));
    }).on('error', reject);
  });
}

(async () => {
  // ---- Setup: sibling dirs feat/ and feat-evil/ ----
  const tmp = fs.mkdtempSync(path.join(require('os').tmpdir(), 'pmos-serve-test-'));
  const safe = path.join(tmp, 'feat');
  const evil = path.join(tmp, 'feat-evil');
  fs.mkdirSync(safe); fs.mkdirSync(evil);
  fs.writeFileSync(path.join(safe, 'index.html'), '<h1>safe</h1>');
  fs.writeFileSync(path.join(safe, 'app.css'), 'body{color:red}');
  fs.writeFileSync(path.join(evil, 'secret.txt'), 'SECRET-SHOULD-NOT-LEAK');

  // Pick a high non-privileged starting port; serve.js will scan up if taken.
  const startPort = 40000 + Math.floor(Math.random() * 10000);
  const server = await start({ root: safe, port: startPort, portFile: null });
  const port = server.address().port;
  const base = `http://127.0.0.1:${port}`;

  // Test 1: literal `..` (Node HTTP parser collapses these — should 404)
  await test('literal /../feat-evil/secret.txt returns 404', async () => {
    const r = await get(`${base}/../feat-evil/secret.txt`);
    assert(r.status === 404, `expected 404, got ${r.status}`);
    assert(!/SECRET/.test(r.body), `body must not leak secret; got: ${r.body}`);
  });

  // Test 2: URL-encoded `..` (the realistic attack path)
  await test('URL-encoded %2E%2E/feat-evil/secret.txt returns 4xx (no leak)', async () => {
    const r = await get(`${base}/%2E%2E/feat-evil/secret.txt`);
    assert(r.status >= 400 && r.status < 500, `expected 4xx, got ${r.status}`);
    assert(!/SECRET/.test(r.body), `body must not leak secret; got: ${JSON.stringify(r.body)}`);
  });

  // Test 3: prefix-confusion — request must NOT escape root by sharing a prefix
  await test('prefix-confusion (root="feat", request "/%2E%2E/feat-evil") blocked', async () => {
    const r = await get(`${base}/%2E%2E/feat-evil/secret.txt`);
    assert(!/SECRET/.test(r.body), 'prefix-confusion path-traversal regression');
  });

  // Test 4: MIME map — every extension declared by FR-06 returns the right Content-Type
  await test('MIME map serves text/html, text/css with charset', async () => {
    const html = await get(`${base}/index.html`);
    assert(html.status === 200 && /text\/html; charset=utf-8/.test(html.headers['content-type']),
      `index.html ctype wrong: ${html.headers['content-type']}`);
    const css = await get(`${base}/app.css`);
    assert(css.status === 200 && /text\/css; charset=utf-8/.test(css.headers['content-type']),
      `app.css ctype wrong: ${css.headers['content-type']}`);
  });

  server.close();
  // Cleanup
  fs.rmSync(tmp, { recursive: true, force: true });

  console.log(`\n${passed} passed, ${failed} failed`);
  process.exit(failed > 0 ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(2); });
