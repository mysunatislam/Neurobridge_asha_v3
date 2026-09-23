const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { Detector } = require('../src/eye-signal.js');

function feed(values, interval = 1 / 30) {
  const detector = new Detector(), events = [];
  values.forEach((ear, i) => {
    const event = detector.update(i * interval, ear, ear, .45);
    if (event) events.push(event);
  });
  return events;
}
const flat = (n, value) => Array(n).fill(value);

test('screenshot-like 0.45 to 0.39 dip counts after reopening', () => {
  const events = feed([...flat(25, .45), .43, .40, .39, .40, .43, ...flat(4, .45)]);
  assert.equal(events.length, 1);
  assert.ok(events[0].relativeDepth > .1);
});
test('open, fully closed hold, open, rapid dips each complete exactly once', () => {
  const values = [...flat(20, .45), .34, .12, ...flat(60, .08), .34, ...flat(8, .45)];
  for (let i = 0; i < 4; i++) values.push(.42, .38, .39, .43, .45, .45, .45);
  const events = feed(values);
  assert.equal(events.length, 5);
  assert.equal(events[0].held, true);
});
test('flat eye signal, one-frame dip and one-eye glitch do not count', () => {
  assert.equal(feed([...flat(20, .45), .44, .43, .45, ...flat(20, .45)]).length, 0);
  assert.equal(feed([...flat(20, .45), .3, ...flat(20, .45)]).length, 0);
  const detector = new Detector(), events = [];
  for (let i = 0; i < 45; i++) {
    const left = i === 25 || i === 26 ? .3 : .45;
    const event = detector.update(i / 30, left, .45, .45);
    if (event) events.push(event);
  }
  assert.equal(events.length, 0);
});
test('symmetric smile stays balanced with neutral baseline; uncalibrated is unknown', () => {
  const sandbox = { window: { NF_LM: {} } };
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(require.resolve('../utils/metrics.js'), 'utf8'), sandbox);
  const points = Array.from({ length: 468 }, () => ({ x: .5, y: .5 }));
  points[33] = { x: .35, y: .4 }; points[263] = { x: .65, y: .4 };
  points[61] = { x: .42, y: .58 }; points[291] = { x: .58, y: .58 };
  const neutral = { cornerLX: .42, cornerRX: .58, cornerLY: .58, cornerRY: .58, head: { roll: 0 } };
  points[61] = { x: .40, y: .55 }; points[291] = { x: .60, y: .55 };
  const balanced = sandbox.window.NF_metrics.smileSideExcursions(points, neutral);
  assert.equal(balanced.score, 100);
  assert.equal(balanced.valid, true);
  const unknown = sandbox.window.NF_metrics.smileSideExcursions(points, null);
  assert.equal(unknown.valid, false);
  points[61] = { x: .40, y: .58 };
  assert.ok(sandbox.window.NF_metrics.smileSideExcursions(points, neutral).score < 55);
});
