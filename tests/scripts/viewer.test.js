'use strict';
// JSDOM unit tests for assets/viewer.js (T3, FR-05/FR-22/FR-26/FR-40).
// Run via: bash tests/scripts/assert_viewer_js_unit.sh

const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const REPO = path.resolve(__dirname, '..', '..');
const VIEWER_PATH = path.join(REPO, 'plugins/pmos-toolkit/skills/_shared/html-authoring/assets/viewer.js');
const FIXTURE = path.join(__dirname, 'fixtures', 'index-min.html');

const VIEWER_SRC = fs.readFileSync(VIEWER_PATH, 'utf8');
const INDEX_HTML = fs.readFileSync(FIXTURE, 'utf8');

let passed = 0, failed = 0;

function test(name, fn) {
  try { fn(); console.log(`  ok  ${name}`); passed++; }
  catch (e) { console.log(`  FAIL ${name}\n       ${e.stack || e.message}`); failed++; }
}

function assert(cond, msg) { if (!cond) throw new Error(msg); }

function makeDom({ url, html = INDEX_HTML, sessionStorage } = {}) {
  const dom = new JSDOM(html, { url, runScripts: 'outside-only', pretendToBeVisual: true });
  if (sessionStorage) {
    Object.defineProperty(dom.window, 'sessionStorage', { configurable: true, value: sessionStorage });
  }
  return dom;
}

function loadViewer(dom) {
  // Eval inside the JSDOM window so document/sessionStorage refer to the fixture.
  dom.window.eval(VIEWER_SRC);
  // Fire DOMContentLoaded so init() runs (viewer.js attaches via DOMContentLoaded).
  const ev = new dom.window.Event('DOMContentLoaded', { bubbles: true });
  dom.window.document.dispatchEvent(ev);
}

// ---- Test 1: file:// protocol → fallback banner -------------------------
test('file:// protocol renders fallback banner (FR-40)', () => {
  const dom = makeDom({ url: 'file:///tmp/feature/index.html' });
  loadViewer(dom);
  const banner = dom.window.document.querySelector('.pmos-fallback-banner');
  assert(banner, 'expected .pmos-fallback-banner element');
  assert(/file:\/\//i.test(banner.textContent), `banner text missing file:// notice; got: ${banner.textContent}`);
  // Sidebar links must use target="_blank" on file:// (no iframe).
  const sidebarLinks = dom.window.document.querySelectorAll('.pmos-sidebar a.pmos-sidebar-item, .pmos-sidebar a.pmos-sidebar-sub');
  assert(sidebarLinks.length > 0, 'expected sidebar links to be built from manifest');
  let allBlank = true;
  sidebarLinks.forEach((a) => { if (a.getAttribute('target') !== '_blank') allBlank = false; });
  assert(allBlank, 'expected every sidebar link to have target="_blank" on file://');
  // No iframe on file:// (FR-40).
  const iframe = dom.window.document.querySelector('.pmos-main iframe');
  assert(!iframe, 'expected NO iframe on file:// fallback');
});

// ---- Test 2: sessionStorage QuotaExceededError → in-memory fallback -----
test('sessionStorage failure falls through to in-memory state (FR-26)', () => {
  const throwingStore = {
    setItem() { const e = new Error('quota'); e.name = 'QuotaExceededError'; throw e; },
    getItem() { const e = new Error('security'); e.name = 'SecurityError'; throw e; },
    removeItem() {},
  };
  const dom = makeDom({ url: 'http://localhost:8000/index.html', sessionStorage: throwingStore });
  loadViewer(dom);
  const api = dom.window.__pmosViewer;
  assert(api && typeof api.safeSessionSet === 'function' && typeof api.safeSessionGet === 'function',
    'viewer must expose __pmosViewer.safeSessionSet/safeSessionGet');
  // Set should not throw; subsequent get returns the stored value via in-memory fallback.
  api.safeSessionSet('pmos.quickstart.seen', '1');
  const v = api.safeSessionGet('pmos.quickstart.seen');
  assert(v === '1', `expected '1' from in-memory fallback, got ${JSON.stringify(v)}`);
  // Quickstart banner therefore should NOT re-show after dismiss within session.
  assert(api.isQuickstartSeen() === true, 'isQuickstartSeen() should reflect in-memory dismiss');
});

// ---- Test 3: legacy-md shim renders <pre class="pmos-legacy-md"> --------
test('legacy-md shim renders <pre class="pmos-legacy-md"> (FR-22)', () => {
  const dom = makeDom({ url: 'http://localhost:8000/index.html' });
  loadViewer(dom);
  const api = dom.window.__pmosViewer;
  assert(api && typeof api.renderLegacyMdShim === 'function',
    'viewer must expose __pmosViewer.renderLegacyMdShim(source, path)');
  api.renderLegacyMdShim('# Hello\n\nbody-line', 'legacy.md');
  const pre = dom.window.document.querySelector('main.pmos-main pre.pmos-legacy-md');
  assert(pre, 'expected <pre class="pmos-legacy-md"> in main pane');
  assert(pre.textContent.indexOf('# Hello') !== -1, 'legacy MD source not embedded in <pre>');
  // Must include the toolbar message (FR-22).
  const banner = dom.window.document.querySelector('main.pmos-main .pmos-legacy-md-banner');
  assert(banner, 'expected .pmos-legacy-md-banner advisory');
  assert(/legacy markdown/i.test(banner.textContent), `legacy-md banner text wrong: ${banner.textContent}`);
});

// ---- Test 4: manifest `id` field honored over path-derived slug -----------
test('artifactSlug prefers manifest.id over derived path slug', () => {
  const dom = makeDom({ url: 'http://localhost:8000/index.html' });
  loadViewer(dom);
  const api = dom.window.__pmosViewer;
  assert(api && typeof api.artifactSlug === 'function', 'viewer must expose __pmosViewer.artifactSlug');
  const withId = api.artifactSlug({ id: '01-requirements', path: '01_requirements.html', title: 'Requirements' });
  assert(withId === '01-requirements', `expected '01-requirements' (manifest id), got '${withId}'`);
  const noId   = api.artifactSlug({ path: '02_spec.html', title: 'Spec' });
  assert(noId === '02-spec', `expected '02-spec' (path-derived), got '${noId}'`);
  const empty  = api.artifactSlug({});
  assert(empty === 'untitled', `expected 'untitled' (fallback), got '${empty}'`);
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
