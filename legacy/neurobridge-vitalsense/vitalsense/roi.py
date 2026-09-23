"""ROI definitions for rPPG using MediaPipe Face Mesh (468 landmarks).

Stable skin regions: forehead, left cheek, right cheek, nose bridge.
Explicitly excluded: eyes, lips, beard/jaw rim, hair, shadows.

This module has NO hard dependency on mediapipe/opencv. When landmarks are
available it maps them to polygonal ROIs; otherwise callers fall back to a
center-crop ROI so the pipeline stays testable offline.
"""

from dataclasses import dataclass

# MediaPipe Face Mesh landmark indices (canonical 468 topology).
# Subsets chosen to sit inside stable skin, away from eyes/lips/edges.
FOREHEAD_IDX = [10, 67, 69, 104, 108, 151, 337, 338, 299, 296, 284, 251]
LEFT_CHEEK_IDX = [123, 147, 213, 192, 214, 177, 205, 137, 227, 116]
RIGHT_CHEEK_IDX = [352, 376, 433, 416, 434, 447, 425, 366, 447, 345]
NOSE_BRIDGE_IDX = [6, 197, 195, 5, 4, 51, 45, 220, 115, 218]

# Regions to exclude (mask out): eyes + lips + jaw rim (beard).
EYE_LEFT_IDX = [33, 133, 159, 145, 153, 154, 155, 133]
EYE_RIGHT_IDX = [362, 263, 386, 374, 380, 381, 382, 362]
LIPS_OUTER_IDX = [61, 146, 91, 181, 84, 17, 314, 405, 321, 375, 291, 409,
                  270, 269, 267, 0, 37, 39, 40, 185]
JAW_RIM_IDX = [136, 172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67]


@dataclass
class ROIWeight:
    name: str
    weight: float  # fusion weight; cheeks dominate, forehead secondary


ROI_WEIGHTS = [
    ROIWeight("left_cheek", 0.35),
    ROIWeight("right_cheek", 0.35),
    ROIWeight("forehead", 0.20),
    ROIWeight("nose_bridge", 0.10),
]


def roi_names():
    return [r.name for r in ROI_WEIGHTS]


def fuse_roi_means(roi_means: dict) -> tuple:
    """Fuse per-ROI (r,g,b) means into one weighted (r,g,b) triple.

    roi_means: {roi_name: (r, g, b)}. Missing ROIs are skipped and weights
    renormalized so tracking survives partial occlusion.
    """
    num_r = num_g = num_b = den = 0.0
    wmap = {r.name: r.weight for r in ROI_WEIGHTS}
    for name, (r, g, b) in roi_means.items():
        w = wmap.get(name, 0.0)
        if w <= 0:
            continue
        num_r += w * r
        num_g += w * g
        num_b += w * b
        den += w
    if den <= 0:
        raise ValueError("no valid ROIs to fuse")
    return (num_r / den, num_g / den, num_b / den)


def roi_stability(prev_centers: dict, cur_centers: dict, frame_diag: float) -> float:
    """0..1 stability score from ROI center displacement.

    prev/cur_centers: {roi_name: (x, y)} in pixels.
    frame_diag: image diagonal in pixels for normalization.
    1.0 = perfectly still, decays as displacement grows.
    """
    if not prev_centers or not cur_centers or frame_diag <= 0:
        return 0.5
    disp = []
    for k, c in cur_centers.items():
        p = prev_centers.get(k)
        if p is None:
            continue
        dx, dy = c[0] - p[0], c[1] - p[1]
        disp.append((dx * dx + dy * dy) ** 0.5 / frame_diag)
    if not disp:
        return 0.5
    mean_disp = sum(disp) / len(disp)
    # 0.5% of diagonal -> ~1.0; 5% -> ~0.0
    score = max(0.0, min(1.0, 1.0 - mean_disp / 0.05))
    return score


def extract_roi_means_mediapipe(frame_bgr, face_landmarks):
    """Adapter stub: frame + MediaPipe landmarks -> {roi: (r,g,b)}.

    Requires opencv + mediapipe at call time. Kept out of the hot path so
    unit tests never import heavy deps. Production (Kotlin/C++) mirrors this
    mapping with the same index sets.
    """
    try:
        import cv2  # type: ignore
        import numpy as np  # type: ignore
    except ImportError as e:
        raise RuntimeError("extract_roi_means_mediapipe needs opencv+numpy") from e
    idx_map = {
        "forehead": FOREHEAD_IDX,
        "left_cheek": LEFT_CHEEK_IDX,
        "right_cheek": RIGHT_CHEEK_IDX,
        "nose_bridge": NOSE_BRIDGE_IDX,
    }
    h, w = frame_bgr.shape[:2]
    out = {}
    pts = [(lm.x * w, lm.y * h) for lm in face_landmarks.landmark]
    for name, idxs in idx_map.items():
        poly = [(pts[i][0], pts[i][1]) for i in idxs if i < len(pts)]
        if len(poly) < 3:
            continue
        import numpy as np
        mask = np.zeros((h, w), dtype=np.uint8)
        cv2.fillPoly(mask, [np.array(poly, dtype=np.int32)], 255)
        mean_b, mean_g, mean_r, _ = cv2.mean(frame_bgr, mask=mask)
        out[name] = (mean_r, mean_g, mean_b)
    return out
