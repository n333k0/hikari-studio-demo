#!/usr/bin/env node
/**
 * shoot-ar.mjs — open a PDP's "Ver en tu espacio" modal, wait for the GLB to
 * genuinely finish loading, then screenshot the modal panel and report the
 * resolved camera state + layout fit.
 *
 * The generic shoot.mjs only waits 350ms after --eval, which is nowhere near
 * enough for a ~1.8MB GLB to download, decode and paint — it would silently
 * capture an empty canvas.
 *
 * Headless Chrome has no AR, so `canActivateAR` is false and the modal shows
 * its desktop QR fallback. Pass --phone to force the supported-device layout
 * (CTA + note visible, QR hidden) so the reported panel height matches what a
 * real phone gets.
 *
 * This verifies the 3D *preview* only. It says nothing about the actual AR
 * session — see docs/verification-policy.md, "Hardware-dependent features".
 *
 * Usage: node shoot-ar.mjs <url> <abs-out.png> [width] [height] [--phone]
 */
import { chromium } from 'playwright';
import { statSync } from 'node:fs';

const args = process.argv.slice(2);
const phone = args.includes('--phone');
const [url, out, w, h] = args.filter((a) => !a.startsWith('--'));
if (!url || !out) { console.error('usage: shoot-ar.mjs <url> <out.png> [w] [h] [--phone]'); process.exit(1); }
const width = parseInt(w || '390', 10);
const height = parseInt(h || '844', 10);

const browser = await chromium.launch({
  headless: true,
  args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'],
});
const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 2 });

const errors = [];
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));

await page.goto(url, { waitUntil: 'load', timeout: 60000 });
await page.evaluate(() => (document.fonts ? document.fonts.ready : Promise.resolve())).catch(() => {});

// open through the real UI path so openModal()/reframeViewer() are exercised
await page.click('[data-modal-open="modal-ar"]');

const loadState = await page.evaluate(async () => {
  const mv = document.getElementById('arViewer');
  if (!mv) return 'no viewer';
  if (mv.loaded) return 'already';
  await new Promise((res) => {
    const t = setTimeout(res, 45000);
    mv.addEventListener('load', () => { clearTimeout(t); res(); }, { once: true });
  });
  return mv.loaded ? 'loaded' : 'timeout';
});

if (phone) {
  await page.evaluate(() => {
    document.getElementById('arActivateBtn').hidden = false;
    document.getElementById('arSupportedNote').hidden = false;
    document.getElementById('arQrBlock').hidden = true;
    document.getElementById('arDesktopNote').hidden = true;
  });
}

await page.waitForTimeout(2500);

const info = await page.evaluate(() => {
  const mv = document.getElementById('arViewer');
  const panel = document.querySelector('#modal-ar .modal__panel');
  const r = mv.getBoundingClientRect();
  const orbit = mv.getCameraOrbit();
  return {
    loaded: mv.loaded,
    orbitRadius: +orbit.radius.toFixed(3),
    orbitPhiDeg: +((orbit.phi * 180) / Math.PI).toFixed(1),
    target: mv.getCameraTarget().toString(),
    fov: +mv.getFieldOfView().toFixed(2),
    viewer: { w: Math.round(r.width), h: Math.round(r.height), aspect: +(r.width / r.height).toFixed(3) },
    panelScrollH: panel.scrollHeight,
    panelClientH: panel.clientHeight,
    panelOverflows: panel.scrollHeight > panel.clientHeight + 1,
    docOverflowX: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
  };
});

await page.locator('#modal-ar .modal__panel').screenshot({ path: out });
console.log(JSON.stringify({ url, viewport: `${width}x${height}`, phone, loadState, ...info, consoleErrors: errors }, null, 2));
console.log(`wrote ${out} (${statSync(out).size} bytes)`);
await browser.close();
