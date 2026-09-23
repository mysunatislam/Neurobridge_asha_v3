const test = require('node:test');
const assert = require('node:assert/strict');
const { Tracker } = require('../src/activity.js');

function landmarks() {
  const lm = Array.from({ length: 478 }, () => ({ x: .5, y: .5, z: 0 }));
  const set = (i, x, y) => { lm[i] = { x, y, z: 0 }; };
  set(234, .3, .5); set(454, .7, .5);
  set(33, .35, .42); set(133, .42, .42); set(263, .65, .42); set(362, .58, .42);
  set(105, .39, .36); set(334, .61, .36);
  set(116, .39, .52); set(345, .61, .52);
  set(61, .42, .58); set(291, .58, .58);
  set(13, .5, .57); set(14, .5, .59);
  return lm;
}
function exercise(change) {
  const tracker = new Tracker(), neutral = landmarks();
  for (let i = 0; i < 44; i++) assert.equal(tracker.update(neutral).ready, false);
  assert.equal(tracker.update(neutral).ready, true);
  const expressive = landmarks(); change(expressive);
  let result;
  for (let i = 0; i < 8; i++) result = tracker.update(expressive);
  return { tracker, result, neutral };
}

test('AU panel learns neutral once instead of comparing every frame against itself', () => {
  const { tracker, result, neutral } = exercise(lm => { lm[105].y -= .02; lm[334].y -= .02; });
  assert.ok(result.values.AU1 > 75);
  assert.equal(result.values.AU4, 0);
  for (let i = 0; i < 10; i++) tracker.update(neutral);
  assert.ok(tracker.values.AU1 < 5);
  tracker.reset();
  assert.equal(tracker.update(neutral).ready, false);
});
test('all six indicators respond to their corresponding geometry', () => {
  const cases = [
    ['AU1', lm => { lm[105].y -= .02; lm[334].y -= .02; }],
    ['AU4', lm => { lm[105].y += .02; lm[334].y += .02; }],
    ['AU6', lm => { lm[116].y -= .02; lm[345].y -= .02; }],
    ['AU12', lm => { lm[61].y -= .025; lm[291].y -= .025; }],
    ['AU20', lm => { lm[61].x -= .02; lm[291].x += .02; }],
    ['AU25', lm => { lm[13].y -= .04; lm[14].y += .04; }]
  ];
  for (const [key, change] of cases) {
    const { result } = exercise(change);
    assert.ok(result.values[key] > 60, key + ' should move, got ' + result.values[key]);
  }
});
test('invalid landmark geometry is not treated as 0% activity', () => {
  const tracker = new Tracker();
  assert.equal(tracker.update([]).invalid, true);
  assert.equal(tracker.samples.length, 0);
});
