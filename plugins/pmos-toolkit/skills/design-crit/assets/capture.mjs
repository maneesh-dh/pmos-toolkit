#!/usr/bin/env node
/**
 * design-crit capture script
 *
 * Modes:
 *   crawl    — start at a URL, follow same-origin links breadth-first up to --depth
 *   journey  — replay a config-defined sequence of steps (goto/click/fill/waitFor)
 *   files    — render a list of local HTML files (wireframes/prototype output)
 *
 * Output: PNG screenshots in --out, plus manifest.json with
 *   { source, mode, viewport, captures: [{ id, url|file, title, path, journey?, step? }] }
 *
 * Usage:
 *   node capture.mjs --mode crawl   --url <start>          --out <dir> [--depth 1] [--max 30] [--viewport 1440x900]
 *   node capture.mjs --mode journey --config <path.json>   --out <dir> [--viewport 1440x900]
 *   node capture.mjs --mode files   --files a.html,b.html  --out <dir> [--viewport 1440x900]
 *
 * Auth:
 *   --storage-state <path.json>   Reuse a saved Playwright storageState (cookies + localStorage)
 *   --basic-auth user:pass        HTTP basic auth header
 *
 * Journey config schema (mode=journey):
 *   {
 *     "baseUrl": "https://app.example.com",
 *     "viewport": { "width": 1440, "height": 900 },
 *     "journeys": [
 *       {
 *         "id": "signup",
 *         "name": "New user signup",
 *         "steps": [
 *           { "action": "goto",     "url": "/signup",                      "screenshot": "01-landing" },
 *           { "action": "fill",     "selector": "input[name=email]",       "value": "qa+1@example.com" },
 *           { "action": "fill",     "selector": "input[name=password]",    "value": "Pa55word!" },
 *           { "action": "click",    "selector": "button[type=submit]",     "screenshot": "02-submitted" },
 *           { "action": "waitFor",  "selector": "h1:has-text('Welcome')",  "screenshot": "03-onboarding" }
 *         ]
 *       }
 *     ]
 *   }
 *
 * Exit codes: 0 ok, 1 args/usage, 2 runtime, 3 dependency missing.
 */

import { mkdir, readFile, writeFile, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { resolve, join, basename, extname, dirname } from 'node:path';
import { pathToFileURL } from 'node:url';

let chromium;
try {
  ({ chromium } = await import('playwright'));
} catch {
  console.error('[capture] playwright is not installed. Install with:\n  npm i -g playwright && npx playwright install chromium');
  process.exit(3);
}

const args = parseArgs(process.argv.slice(2));
if (!args.mode) usage('missing --mode');
if (!args.out) usage('missing --out');

const outDir = resolve(args.out);
await mkdir(outDir, { recursive: true });

const viewport = parseViewport(args.viewport ?? '1440x900');
const browser = await chromium.launch({ headless: true });
const ctxOpts = { viewport };
if (args['storage-state']) ctxOpts.storageState = resolve(args['storage-state']);
if (args['basic-auth']) {
  const [u, p] = args['basic-auth'].split(':');
  ctxOpts.httpCredentials = { username: u, password: p };
}
const context = await browser.newContext(ctxOpts);
const page = await context.newPage();

const captures = [];
const errors = [];

try {
  if (args.mode === 'crawl') await runCrawl();
  else if (args.mode === 'journey') await runJourney();
  else if (args.mode === 'files') await runFiles();
  else usage(`unknown mode: ${args.mode}`);
} catch (err) {
  console.error('[capture] runtime error:', err.message);
  errors.push({ fatal: true, message: err.message });
} finally {
  await context.close();
  await browser.close();
}

const manifest = {
  generated: new Date().toISOString(),
  mode: args.mode,
  source: args.url ?? args.config ?? args.files,
  viewport,
  captures,
  errors,
};
await writeFile(join(outDir, 'manifest.json'), JSON.stringify(manifest, null, 2));
console.log(`[capture] wrote ${captures.length} screenshots → ${outDir}`);
if (errors.length) console.log(`[capture] ${errors.length} non-fatal errors logged in manifest.json`);
process.exit(errors.some((e) => e.fatal) ? 2 : 0);

// ── crawl ───────────────────────────────────────────────────────────────
async function runCrawl() {
  const start = args.url;
  if (!start) usage('crawl mode requires --url');
  const depth = Number(args.depth ?? 1);
  const max = Number(args.max ?? 30);
  const origin = new URL(start).origin;
  const seen = new Set();
  const queue = [{ url: start, d: 0 }];

  while (queue.length && captures.length < max) {
    const { url, d } = queue.shift();
    if (seen.has(url)) continue;
    seen.add(url);
    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
      const title = (await page.title()) || basename(new URL(url).pathname) || 'index';
      const id = String(captures.length + 1).padStart(2, '0') + '-' + slug(title);
      const file = join(outDir, `${id}.png`);
      await page.screenshot({ path: file, fullPage: true });
      captures.push({ id, url, title, path: file, depth: d });
      console.log(`[capture] ${id}  ${url}`);
      if (d < depth) {
        const links = await page.$$eval('a[href]', (as) => as.map((a) => a.href));
        for (const link of links) {
          if (link.startsWith(origin) && !seen.has(link)) queue.push({ url: link, d: d + 1 });
        }
      }
    } catch (err) {
      errors.push({ url, message: err.message });
    }
  }
}

// ── journey ─────────────────────────────────────────────────────────────
async function runJourney() {
  if (!args.config) usage('journey mode requires --config');
  const cfg = JSON.parse(await readFile(resolve(args.config), 'utf8'));
  const base = cfg.baseUrl ?? '';
  for (const journey of cfg.journeys ?? []) {
    let stepIdx = 0;
    for (const step of journey.steps ?? []) {
      stepIdx++;
      try {
        if (step.action === 'goto') {
          const target = step.url?.startsWith('http') ? step.url : base + (step.url ?? '');
          await page.goto(target, { waitUntil: 'networkidle', timeout: 30000 });
        } else if (step.action === 'click') {
          await page.click(step.selector, { timeout: 10000 });
          await page.waitForLoadState('networkidle', { timeout: 10000 }).catch(() => {});
        } else if (step.action === 'fill') {
          await page.fill(step.selector, step.value ?? '');
        } else if (step.action === 'waitFor') {
          await page.waitForSelector(step.selector, { timeout: 15000 });
        } else if (step.action === 'press') {
          await page.keyboard.press(step.key);
        }
        if (step.screenshot) {
          const id = `${journey.id}-${String(stepIdx).padStart(2, '0')}-${slug(step.screenshot)}`;
          const file = join(outDir, `${id}.png`);
          await page.screenshot({ path: file, fullPage: true });
          captures.push({ id, journey: journey.id, journeyName: journey.name, step: stepIdx, action: step.action, path: file, url: page.url() });
          console.log(`[capture] ${id}  (${step.action})`);
        }
      } catch (err) {
        errors.push({ journey: journey.id, step: stepIdx, action: step.action, message: err.message });
        console.error(`[capture] journey=${journey.id} step=${stepIdx} failed: ${err.message}`);
      }
    }
  }
}

// ── files ───────────────────────────────────────────────────────────────
async function runFiles() {
  if (!args.files) usage('files mode requires --files');
  const list = args.files.split(',').map((f) => f.trim()).filter(Boolean);
  for (const f of list) {
    const abs = resolve(f);
    if (!existsSync(abs)) {
      errors.push({ file: f, message: 'not found' });
      continue;
    }
    const url = pathToFileURL(abs).href;
    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
      const title = (await page.title()) || basename(abs, extname(abs));
      const id = String(captures.length + 1).padStart(2, '0') + '-' + slug(title || basename(abs));
      const out = join(outDir, `${id}.png`);
      await page.screenshot({ path: out, fullPage: true });
      captures.push({ id, file: abs, title, path: out });
      console.log(`[capture] ${id}  ${abs}`);
    } catch (err) {
      errors.push({ file: f, message: err.message });
    }
  }
}

// ── helpers ─────────────────────────────────────────────────────────────
function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (!next || next.startsWith('--')) out[key] = true;
      else { out[key] = next; i++; }
    }
  }
  return out;
}

function parseViewport(s) {
  const [w, h] = s.split('x').map(Number);
  return { width: w || 1440, height: h || 900 };
}

function slug(s) {
  return String(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60) || 'screen';
}

function usage(msg) {
  if (msg) console.error(`[capture] ${msg}`);
  console.error('Usage: see comment header at top of capture.mjs');
  process.exit(1);
}
