#!/usr/bin/env node
/**
 * shoot.mjs — dedicated screenshot capture (Playwright).
 *
 * ONE responsibility: open a URL at a given viewport, optionally run a snippet
 * (e.g. scroll) before capturing, write a PNG to an ABSOLUTE path, then verify
 * the bytes landed. No scratchpad. No dependency on chrome-devtools-axi.
 *
 * Usage:
 *   node shoot.mjs --url <url> --out <abs.png> [--width 1440] [--height 900]
 *                  [--eval "<js run before capture>"] [--full-page]
 *
 * Exit codes: 0 = a non-empty image was written & verified; 1 = loud failure.
 */
import { chromium } from 'playwright';
import { existsSync, statSync, mkdirSync } from 'node:fs';
import { dirname, isAbsolute } from 'node:path';

const argv = process.argv.slice(2);
const opt = (name, def = null) => {
  const i = argv.indexOf(name);
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : def;
};
const flag = (name) => argv.includes(name);
const die = (msg) => { console.error(`shoot: ERROR ${msg}`); process.exit(1); };

const url = opt('--url');
const out = opt('--out');
const width = parseInt(opt('--width', '1440'), 10);
const height = parseInt(opt('--height', '900'), 10);
const evalJs = opt('--eval', null);
const fullPage = flag('--full-page');

if (!url) die('missing --url');
if (!out) die('missing --out');
if (!isAbsolute(out)) die(`--out must be an absolute path: ${out}`);
if (!Number.isFinite(width) || !Number.isFinite(height)) die('bad --width/--height');

mkdirSync(dirname(out), { recursive: true });

let browser;
try {
  browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1 });
  await page.goto(url, { waitUntil: 'load', timeout: 30000 });
  // let web fonts settle so text renders identically to production
  await page.evaluate(() => (document.fonts ? document.fonts.ready : Promise.resolve())).catch(() => {});
  if (evalJs) {
    await page
      .evaluate(`(()=>{ ${evalJs} })()`)
      .catch((e) => console.error(`shoot: warn --eval failed: ${e.message}`));
  }
  await page.waitForTimeout(350);
  await page.screenshot({ path: out, fullPage });
} catch (e) {
  die(`capture failed: ${e.message}`);
} finally {
  if (browser) await browser.close().catch(() => {});
}

// verify + FAIL LOUDLY if the image is missing/empty
if (!existsSync(out) || statSync(out).size === 0) die(`no image written at ${out}`);
console.log(`shoot: ok ${out} (${statSync(out).size} bytes, ${width}x${height})`);
