const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');

function hand(offset, extended) {
  const lm = Array.from({ length: 21 }, () => ({ x: .5 + offset, y: .65, z: 0 }));
  lm[0] = { x: .45 + offset, y: .85, z: 0 };
  [[5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16], [17, 18, 19, 20]]
    .forEach((chain, i) => chain.forEach((index, j) => {
      lm[index] = { x: .32 + i * .09 + offset,
        y: extended[i] ? [.55, .45, .35, .25][j] : [.55, .45, .53, .61][j], z: 0 };
    }));
  [[1, .39, .69], [2, .34, .62], [3, .29, .55], [4, .24, .48]]
    .forEach(([index, x, y]) => { lm[index] = { x: x + offset, y, z: 0 }; });
  return lm;
}

(async () => {
  const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
  const browser = await chromium.launch({
    ...(fs.existsSync(chrome) ? { executablePath: chrome } : {}), headless: true,
    args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream']
  });
  try {
    const context = await browser.newContext({ permissions: ['camera'] });
    const left = hand(-.12, [1, 1, 1, 1]), right = hand(.12, [1, 0, 0, 0]);
    const stub = `export class FilesetResolver { static async forVisionTasks() { return {}; } }
      export class HandLandmarker {
        static async createFromOptions(_vision, options) { window.__handOptions = options; return new HandLandmarker(); }
        detectForVideo() { return { landmarks: [${JSON.stringify(right)}, ${JSON.stringify(left)}],
          handednesses: [[{categoryName:'Right'}], [{categoryName:'Left'}]] }; }
      }`;
    await context.route('**/vendor/vision_bundle.mjs', route => route.fulfill({
      status: 200, contentType: 'text/javascript', body: stub
    }));
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto('http://127.0.0.1:4173/fingerspeak.html');
    await page.getByRole('button', { name: 'Enable camera' }).click();
    await page.waitForFunction(() => document.querySelector('#handCount').textContent === '2/2 tracked', null, { timeout: 12000 });
    const cards = await page.locator('.auto-hand').allTextContents();
    assert.equal(cards.length, 2);
    assert.match(cards[0], /Left.*index 100%.*middle 100%/);
    assert.match(cards[1], /Right.*index 100%.*middle 0%/);
    assert.equal(await page.evaluate(() => window.__handOptions.numHands), 2);
    assert.equal(await page.locator('#currentGesture').textContent(), '—');
    const oldRaw = Array.from({ length: 20 }, () => Array(63).fill(.2));
    const profile = { version: 2, gestures: ['Rest', 'Yes'].map(name => ({
      name, phrase: name === 'Rest' ? '' : 'Yes.', samples: [{ raw: oldRaw, session: 'prior' }]
    })) };
    await page.locator('#importFile').setInputFiles({ name: 'prior-fingerspeak.json',
      mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(profile)) });
    await page.waitForFunction(() => document.querySelector('#trainStatus').textContent.includes('Older one-hand samples were converted'));
    assert.deepEqual(errors, []);
    console.log('Two-hand overlay, per-hand pose preview, and legacy profile import pass.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
