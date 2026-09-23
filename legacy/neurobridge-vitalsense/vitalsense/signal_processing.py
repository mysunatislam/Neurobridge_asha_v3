"""Signal processing: detrend -> normalize -> bandpass -> FFT HR estimate.

Heart-rate band: 0.7-4.0 Hz (42-240 BPM).
Respiration band: 0.1-0.5 Hz (6-30 br/min).
Green channel is primary; red/blue assist motion-artifact suppression via a
simple chrominance-style correction (G - mean(R,B)) before filtering.
"""

import numpy as np

try:
    from scipy.signal import butter, filtfilt
    _HAS_SCIPY = True
except Exception:
    _HAS_SCIPY = False

HR_LOW, HR_HIGH = 0.7, 4.0
RESP_LOW, RESP_HIGH = 0.1, 0.5


def detrend(x: np.ndarray) -> np.ndarray:
    x = np.asarray(x, dtype=float)
    if x.size < 3:
        return x - x.mean() if x.size else x
    t = np.arange(x.size, dtype=float)
    # linear least-squares detrend (edge-safe, numpy only)
    a, b = np.polyfit(t, x, 1)
    return x - (a * t + b)


def normalize_signal(x: np.ndarray) -> np.ndarray:
    x = np.asarray(x, dtype=float)
    sd = x.std()
    if sd < 1e-9:
        return np.zeros_like(x)
    return (x - x.mean()) / sd


def bandpass(x: np.ndarray, fs: float, low: float, high: float, order: int = 4) -> np.ndarray:
    x = np.asarray(x, dtype=float)
    if x.size < int(fs) + 1:
        return np.zeros_like(x)
    if _HAS_SCIPY:
        nyq = fs / 2.0
        b, a = butter(order, [low / nyq, high / nyq], btype="band")
        # filtfilt needs padlen < size; guard short windows
        padlen = 3 * max(len(a), len(b))
        if x.size <= padlen:
            return normalize_signal(x)
        return filtfilt(b, a, x)
    # Fallback: FFT brick-wall (no scipy on edge target yet)
    X = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(x.size, 1.0 / fs)
    mask = (freqs >= low) & (freqs <= high)
    X[~mask] = 0
    return np.fft.irfft(X, n=x.size)


def chrominance_correct(r: np.ndarray, g: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Lightweight motion suppression: G minus common-mode (R+B)/2 drift."""
    r, g, b = (np.asarray(v, dtype=float) for v in (r, g, b))
    common = (detrend(r) + detrend(b)) / 2.0
    return detrend(g) - 0.5 * common


def _parabolic_peak(freqs: np.ndarray, mag: np.ndarray, k: int) -> float:
    if k <= 0 or k >= len(mag) - 1:
        return float(freqs[k])
    a, b, c = mag[k - 1], mag[k], mag[k + 1]
    denom = a - 2 * b + c
    delta = 0.5 * (a - c) / denom if abs(denom) > 1e-12 else 0.0
    delta = max(-1.0, min(1.0, delta))
    return float(freqs[k] + delta * (freqs[1] - freqs[0]))


def estimate_heart_rate(g: list | np.ndarray, fs: float = 30.0,
                        r: list | np.ndarray | None = None,
                        b: list | np.ndarray | None = None,
                        low: float = HR_LOW, high: float = HR_HIGH) -> dict:
    """Return {bpm, freq_hz, peak_clarity, sqi, spectrum...} from windowed signal."""
    g = np.asarray(g, dtype=float)
    n = g.size
    if n < int(fs * 5):
        return {"bpm": 0.0, "freq_hz": 0.0, "peak_clarity": 0.0, "sqi": 0.0,
                "reliable": False, "reason": "window too short"}
    if r is not None and b is not None:
        sig = chrominance_correct(np.asarray(r), g, np.asarray(b))
    else:
        sig = detrend(g)
    sig = normalize_signal(sig)
    filt = bandpass(sig, fs, low, high)
    if np.allclose(filt, 0):
        return {"bpm": 0.0, "freq_hz": 0.0, "peak_clarity": 0.0, "sqi": 0.0,
                "reliable": False, "reason": "flat signal"}

    # Hann + 4x zero-pad FFT for sub-BPM resolution
    win = np.hanning(n)
    nfft = 4 * n
    spec = np.fft.rfft(filt * win, n=nfft)
    mag = np.abs(spec)
    freqs = np.fft.rfftfreq(nfft, 1.0 / fs)
    band = (freqs >= low) & (freqs <= high)
    if not band.any():
        return {"bpm": 0.0, "freq_hz": 0.0, "peak_clarity": 0.0, "sqi": 0.0,
                "reliable": False, "reason": "band empty"}
    bmag = mag.copy()
    bmag[~band] = 0
    k = int(np.argmax(bmag))
    peak_freq = _parabolic_peak(freqs, mag, k)
    peak_power = float(mag[k] ** 2)
    band_power = float(np.sum(mag[band] ** 2) + 1e-12)
    peak_clarity = peak_power / band_power  # 0..1, sharp peak -> ~high
    # SQI: clarity mapped + kurtosis of filtered signal (pulsatile ~ super-gaussian)
    kurt = float(np.mean(filt ** 4) / (np.mean(filt ** 2) ** 2 + 1e-12) - 3.0)
    sqi = max(0.0, min(1.0, 0.7 * peak_clarity * 4 + 0.3 * min(1.0, max(0.0, kurt / 3.0))))
    bpm = float(peak_freq * 60.0)
    reliable = peak_clarity > 0.08 and (42.0 <= bpm <= 240.0)
    return {"bpm": bpm, "freq_hz": peak_freq, "peak_clarity": float(peak_clarity),
            "sqi": float(sqi), "reliable": bool(reliable),
            "spectrum_freqs": freqs[band].tolist(), "spectrum_mag": mag[band].tolist()}


def estimate_respiration(g: list | np.ndarray, fs: float = 30.0) -> dict:
    g = np.asarray(g, dtype=float)
    if g.size < int(fs * 10):
        return {"breaths_per_min": 0.0, "reliable": False}
    sig = normalize_signal(detrend(g))
    filt = bandpass(sig, fs, RESP_LOW, RESP_HIGH, order=3)
    win = np.hanning(len(filt))
    nfft = 4 * len(filt)
    mag = np.abs(np.fft.rfft(filt * win, n=nfft))
    freqs = np.fft.rfftfreq(nfft, 1.0 / fs)
    band = (freqs >= RESP_LOW) & (freqs <= RESP_HIGH)
    if not band.any() or mag[band].max() < 1e-9:
        return {"breaths_per_min": 0.0, "reliable": False}
    k = int(np.argmax(mag * band))
    return {"breaths_per_min": float(freqs[k] * 60.0), "reliable": True}
