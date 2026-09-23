const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { Watch } = require('../src/lip-watch.js');

test('one-sided lip observation flags only after 60 active seconds', () => {
  const watch = new Watch(60), alerts = [];
  for (let i = 0; i <= 1900; i++) if (watch.update(i / 30, true, 'right')) alerts.push(i);
  assert.equal(alerts.length, 1);
  assert.ok(alerts[0] / 30 >= 60);
  assert.equal(watch.latched, true);
});
test('neutral recovery, changed side, and tracking gap reset sustained watch', () => {
  const watch = new Watch(60);
  for (let i = 0; i <= 900; i++) watch.update(i / 30, true, 'right');
  watch.update(30.1, false, 'right'); watch.update(30.8, false, 'right');
  assert.equal(watch.duration, 0);
  for (let i = 0; i < 900; i++) watch.update(31 + i / 30, true, 'right');
  watch.update(61, true, 'left');
  assert.ok(watch.duration < .1);
  assert.equal(watch.latched, false);
});
test('corner shape change is detected even with centered mouth and moderate roll', () => {
  const sandbox = { window: { NF_LM: {} } }; vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(require.resolve('../utils/metrics.js'), 'utf8'), sandbox);
  const m = sandbox.window.NF_metrics;
  const lm = Array.from({ length: 468 }, () => ({ x: .5, y: .5 }));
  lm[234] = { x: .3, y: .5 }; lm[454] = { x: .7, y: .5 };
  lm[33] = { x: .35, y: .4 }; lm[263] = { x: .65, y: .4 };
  lm[1] = { x: .5, y: .45 };
  lm[61] = { x: .42, y: .6 }; lm[291] = { x: .58, y: .6 };
  const neutral = { cornerLX: .42, cornerRX: .58, cornerLY: .6, cornerRY: .6, head: { roll: 0 } };
  assert.equal(m.lipAsymmetry(lm, neutral), 0);
  lm[61] = { x: .42, y: .63 }; lm[291] = { x: .58, y: .57 };
  assert.ok(Math.abs(m.lipDeviation(lm, 0)) < .01);
  assert.ok(Math.abs(m.lipAsymmetry(lm, neutral)) > .04);
});
