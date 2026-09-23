const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');

(async () => {
  const chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
  const browser = await chromium.launch({ ...(fs.existsSync(chrome) ? { executablePath: chrome } : {}), headless: true });
  try {
    const context = await browser.newContext();
    const externalRequests = [];
    await context.route(/^https?:\/\/(?!127\.0\.0\.1:4173)/, route => {
      externalRequests.push(route.request().url()); route.abort();
    });
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto('http://127.0.0.1:4173/');
    await page.waitForFunction(() => document.querySelector('#logList').textContent.includes('ready'));
    assert.equal(await page.evaluate(() => typeof window.NF_models), 'undefined');
    assert.equal(externalRequests.some(url => /tensorflow|tf\.min\.js/i.test(url)), false);
    assert.match(await page.locator('h2').allTextContents().then(x => x.join(' ')), /Facial Signal Consistency/);
    const result = await page.evaluate(() => {
      const detector = new NF_eyeSignal.Detector(); let count = 0;
      const sequence = [...Array(25).fill(.45), .43, .40, .39, .40, .43, ...Array(4).fill(.45)];
      sequence.forEach((ear, i) => { if (detector.update(i / 30, ear, ear, .45)) count++; });
      const watch = new NF_lipWatch.Watch(60); let alerts = 0;
      for (let i = 0; i <= 1900; i++) if (watch.update(i / 30, true, 'right')) alerts++;
      return { count, alerts, scoreLabel: document.querySelector('#vMotor').nextElementSibling.textContent };
    });
    assert.equal(result.count, 1); assert.equal(result.alerts, 1);
    assert.match(result.scoreLabel, /tracking consistency/);
    // Drive the actual page's onMesh callback with numeric landmark fixtures;
    // this verifies that the dashboard consumes the new detectors, not merely
    // that their standalone modules were downloaded.
    await page.evaluate(() => {
      window.FaceMesh = class {
        setOptions() {}
        onResults(callback) { window.syntheticMeshResult = callback; }
        async send() {}
      };
      navigator.mediaDevices.getUserMedia = async () => {
        const canvas = document.createElement('canvas'); canvas.width = 640; canvas.height = 480;
        canvas.getContext('2d').fillRect(0, 0, 640, 480);
        return canvas.captureStream(30);
      };
    });
    await page.locator('#btnCamera').click();
    await page.waitForFunction(() => typeof window.syntheticMeshResult === 'function');
    const live = await page.evaluate(async () => {
      const lm = Array.from({ length: 478 }, () => ({ x: .5, y: .5, z: 0 }));
      const p = (i, x, y) => { lm[i] = { x, y, z: 0 }; };
      p(234, .3, .5); p(454, .7, .5); p(10, .5, .2); p(152, .5, .8); p(1, .5, .45);
      p(33, .35, .42); p(133, .42, .42); p(263, .65, .42); p(362, .58, .42);
      p(61, .42, .58); p(291, .58, .58); p(13, .5, .57); p(14, .5, .59);
      p(105, .39, .36); p(334, .61, .36);
      p(116, .39, .52); p(345, .61, .52);
      function eyes(ear) {
        const v = ear * (.07 * 640) / 480;
        for (const i of [160, 158, 385, 387]) p(i, lm[i].x, .42 - v / 2);
        for (const i of [153, 144, 373, 380]) p(i, lm[i].x, .42 + v / 2);
      }
      // Eye samples need distinct x positions for a geometrically valid mesh.
      p(160, .37, .42); p(153, .37, .42); p(158, .40, .42); p(144, .40, .42);
      p(385, .63, .42); p(373, .63, .42); p(387, .60, .42); p(380, .60, .42);
      const tick = async (ear, wait = 34) => {
        eyes(ear); window.syntheticMeshResult({ multiFaceLandmarks: [lm] });
        await new Promise(resolve => setTimeout(resolve, wait));
      };
      for (let i = 0; i < 50; i++) await tick(.45);
      const activityStatus = document.querySelector('#auStatus').textContent;
      const activityAtRest = document.querySelector('#au_AU1').textContent;
      async function exercise(change, key) {
        const saved = lm.map(point => ({ ...point }));
        change();
        for (let i = 0; i < 7; i++) await tick(.45, 1);
        await new Promise(resolve => setTimeout(resolve, 60)); // HUD redraw is intentionally capped at 20 FPS
        await tick(.45, 1);
        const value = Number.parseInt(document.querySelector('#au_' + key).textContent, 10);
        saved.forEach((point, i) => { lm[i] = point; });
        for (let i = 0; i < 10; i++) await tick(.45, 1);
        return value;
      }
      const activity = {
        AU1: await exercise(() => { p(105, .39, .34); p(334, .61, .34); }, 'AU1'),
        AU4: await exercise(() => { p(105, .39, .38); p(334, .61, .38); }, 'AU4'),
        AU6: await exercise(() => { p(116, .39, .50); p(345, .61, .50); }, 'AU6'),
        AU12: await exercise(() => { p(61, .42, .555); p(291, .58, .555); }, 'AU12'),
        AU20: await exercise(() => { p(61, .40, .58); p(291, .60, .58); }, 'AU20'),
        AU25: await exercise(() => { p(13, .5, .53); p(14, .5, .63); }, 'AU25')
      };
      for (const ear of [.43, .40, .39, .40, .43, .45, .45, .45]) await tick(ear);
      const blink = document.querySelector('#vEyeDbg').textContent;
      p(1, .46, .45); p(61, .42, .61); p(291, .58, .55);
      await tick(.45, 60); await tick(.45);
      const lip = document.querySelector('#vDev').textContent;
      const score = document.querySelector('#vMotor').textContent;
      return { blink, lip, score, errors: document.querySelector('#pdErr').textContent,
        activity, activityStatus, activityAtRest };
    });
    assert.match(live.activityStatus, /reference ready/i);
    assert.equal(live.activityAtRest, '0%');
    for (const [key, value] of Object.entries(live.activity))
      assert.ok(value > 60, key + ' should react on the served page; got ' + value);
    assert.match(live.blink, /blinks 1/);
    assert.match(live.lip, /right mouth corner/);
    assert.match(live.lip, /corner asymmetry/);
    assert.ok(Number.parseInt(live.score, 10) >= 90);
    assert.equal(live.errors, '0');
    await page.locator('#btnAuReset').click();
    assert.match(await page.locator('#auStatus').innerText(), /learning neutral/i);
    assert.equal(await page.locator('#au_AU1').innerText(), '—');
    await page.locator('#btnCamera').click();
    assert.deepEqual(errors, []);
    console.log('Current served dashboard: all six activity bars respond to landmark motions and reset; blink and lip fixtures pass; no JS errors.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
