const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');

(async () => {
  const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
  const browser = await chromium.launch({
    ...(fs.existsSync(chrome) ? { executablePath: chrome } : {}), headless: true,
    args: ['--use-fake-ui-for-media-stream', '--use-fake-device-for-media-stream']
  });
  try {
    const context = await browser.newContext({ permissions: ['camera'] });
    await context.route(/^https?:\/\/(?!127\.0\.0\.1:4173)/, route => route.abort());
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto('http://127.0.0.1:4173/');
    await page.getByRole('link', { name: /Open FingerSpeak/ }).click();
    assert.match(page.url(), /fingerspeak\.html$/);
    await page.waitForFunction(() => document.querySelectorAll('#gestureList .gesture-row').length === 5);
    assert.equal(await page.evaluate(() => typeof window.NF_fingerspeakSignal), 'object');
    assert.equal(await page.evaluate(() => typeof window.tf), 'object');
    const persistedShape = await page.evaluate(async () => {
      const url = 'indexeddb://neuroface-fingerspeak-browser-test';
      const model = tf.sequential();
      model.add(tf.layers.dense({ inputShape: [3], units: 2 }));
      await model.save(url);
      await model.save(url); // repeat-save must replace the previous model
      const loaded = await tf.loadLayersModel(url);
      const shape = loaded.outputs[0].shape;
      model.dispose(); loaded.dispose(); await tf.io.removeModel(url);
      return shape;
    });
    assert.equal(persistedShape.at(-1), 2);
    await page.getByRole('button', { name: 'Enable camera' }).click();
    await page.waitForFunction(() => document.querySelector('#statusText').textContent === 'tracking', null, { timeout: 45000 });
    await page.waitForTimeout(2500);
    assert.match(await page.locator('#fpsReadout').textContent(), /\d+ processed fps/);
    assert.deepEqual(errors, []);
    assert.deepEqual(await page.evaluate(() => performance.getEntriesByType('resource')
      .map(entry => entry.name).filter(url => /^https?:\/\/(?!127\.0\.0\.1:4173)/.test(url))), []);
    await page.getByRole('link', { name: /NeuroFace Sense/ }).click();
    assert.match(page.url(), /127\.0\.0\.1:4173\/$/);
    console.log('FingerSpeak navigation, local hand tracker, camera loop, and return link pass.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
