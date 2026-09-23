"""Verify the REAL browser DSP inside demo/vitalsense-real.html.

Extracts the pure signal-processing section (no DOM, no camera) and runs it
in node against synthetic RGB with a known embedded pulse. Fails if the
estimated BPM is off — this tests the shipped file, not a copy.
"""
import re
import subprocess
import sys
from pathlib import Path

HTML = Path(__file__).resolve().parents[1] / "demo" / "vitalsense-real.html"
START = "signal processing: POS algorithm + FFT"
END = "mediapipe face tracking"

text = HTML.read_text(encoding="utf-8")
lines = text.splitlines(keepends=True)
si = next(k for k, l in enumerate(lines) if START in l)
ei = next(k for k, l in enumerate(lines) if END in l)
section = "".join(lines[si:ei])
assert "bandpassFFT" in section, "bandpass stage missing from shipped file"
assert "subtractMovingAverage" in section, "MA detrending missing from shipped file"
assert "peakBin" in section, "parabolic interpolation missing from shipped file"
assert "fftCore" in section and "function ifft" in section, "FFT refactor missing"

harness = section + r"""
// ---- synthetic test: known pulse embedded in RGB ----
function synth(targetBpm, secs, fps, driftAmp, noiseAmp, seed) {
  let s = seed;
  const rnd = () => (s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff - 0.5;
  const f = targetBpm / 60, n = Math.round(secs * fps);
  const R = [], G = [], B = [];
  for (let k = 0; k < n; k++) {
    const t = k / fps;
    const pulse = Math.sin(2 * Math.PI * f * t) + 0.4 * Math.sin(4 * Math.PI * f * t);
    const drift = driftAmp * Math.sin(2 * Math.PI * 0.18 * t);
    R.push(0.60 + 0.004 * pulse + drift + noiseAmp * rnd());
    G.push(0.55 + 0.010 * pulse + drift + noiseAmp * rnd());
    B.push(0.50 + 0.003 * pulse + drift + noiseAmp * rnd());
  }
  return { R, G, B };
}
function measure(targetBpm) {
  const fps = 30;
  const { R, G, B } = synth(targetBpm, 12, fps, 0.02, 0.004, 7);
  const raw = posAlgorithm(R, G, B);
  const filt = bandpassFFT(subtractMovingAverage(detrend(raw), fps), fps, 42/60, 200/60);
  const res = estimatePeakBpm(filt, fps, 42, 200);
  return res ? res.bpm : NaN;
}
const results = [75, 60, 100].map(b => ({ target: b, got: measure(b) }));
console.log(JSON.stringify(results));
for (const r of results) {
  if (!isFinite(r.got) || Math.abs(r.got - r.target) > 2)
    throw new Error(`FAIL target=${r.target} got=${r.got}`);
}
console.log("DSP SYNTHETIC CHECKS PASSED");
"""

tmp = Path(__file__).resolve().parent / "_dsp_check.mjs"
tmp.write_text(harness, encoding="utf-8")
try:
    out = subprocess.run(["node", str(tmp)], capture_output=True, text=True, timeout=60)
finally:
    tmp.unlink(missing_ok=True)
print(out.stdout)
print(out.stderr, file=sys.stderr)
if out.returncode != 0:
    raise SystemExit("node DSP verification FAILED")
