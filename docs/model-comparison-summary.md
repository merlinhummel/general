# Pose Estimation Model Comparison - Quick Reference

## Executive Summary for Hammer Throw Tracking

| Ranking | Model | Best For | Key Advantage | Main Limitation |
|---------|-------|----------|---------------|-----------------|
| 🥇 1st | **YOLOv8-Pose** | Fast movements | 33-36 FPS real-time | Moderate accuracy |
| 🥈 2nd | **MediaPipe** | Mobile apps | 45+ FPS on iOS, cross-platform | Multi-person struggles |
| 🥉 3rd | **HRNet** | Offline analysis | Highest accuracy (77.0 mAP) | Very slow (<12 FPS) |
| 4th | **MMPose** | Research/Custom | Modular, state-of-art | Complex setup |
| 5th | **AlphaPose** | Occlusion handling | Good multi-person | Slower than YOLO |
| 6th | **Apple Vision** | iOS-only apps | Native integration | Low accuracy (32.8 mAP) |
| 7th | **OpenPose** | Multi-person desktop | Robust detection | Too slow for mobile |
| 8th | **PoseNet** | Simple web apps | Lightweight | Outdated, single-person |

---

## Quick Comparison Table

### Accuracy Metrics

| Model | mAP (COCO) | PCKh@0.5 | Keypoints | Year |
|-------|------------|----------|-----------|------|
| HRNet | 77.0 | 92.3% | 17 | 2019 |
| MMPose (RTMPose) | >77.0 | - | Variable | 2020+ |
| AlphaPose | 72.3 | 80% | 17 | 2017 |
| YOLOv8-Pose | ~65-70 | - | 17 | 2023 |
| OpenPose | 61.8 | 77.6% | 18-25 | 2017 |
| **MediaPipe** | **45.0†** | - | **33** | **2020** |
| **Apple Vision** | **32.8†** | - | **19** | **2020** |
| PoseNet | <50 | - | 17 | 2017 |

† Yoga dataset, not COCO

### Mobile Performance (iOS)

| Model | iPhone X | iPhone 15 Pro | On-Device | Platform |
|-------|----------|---------------|-----------|----------|
| QuickPose | - | 120 FPS | ✅ | iOS only |
| MobilePoser | - | 60 FPS | ✅ | iOS only |
| **MediaPipe** | **45 FPS** | **60+ FPS** | ✅ | **Cross-platform** |
| **Apple Vision** | **~30 FPS** | **~60 FPS** | ✅ | **iOS only** |
| YOLOv8-Pose | 10-30 FPS | 30-60 FPS | ⚠️ | Cross-platform |
| MoveNet | 25+ FPS | 30+ FPS | ✅ | Cross-platform |
| HRNet | <5 FPS | <10 FPS | ❌ | Desktop |
| OpenPose | 0.14 FPS | <1 FPS | ❌ | Desktop |

### Sports Performance Rating

| Model | Fast Movement | Occlusion | Temporal | Sports Validated |
|-------|---------------|-----------|----------|------------------|
| **YOLOv8-Pose** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ Badminton |
| **MediaPipe** | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ Various sports |
| HRNet | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ Research |
| MMPose | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ Research |
| AlphaPose | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ Various |
| **Apple Vision** | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ | ⚠️ Fitness only |
| OpenPose | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ | ✅ Various |

---

## Recommendation for HammerTrack

### Primary Recommendation: Multi-Tier System

#### Tier 1: Real-Time Mobile (Choose One)

**Option A: YOLOv8-Pose (BEST for fast movements)**
- **Pros:** Fastest (33-36 FPS), handles motion blur, sports-proven
- **Cons:** Requires CoreML conversion, moderate accuracy
- **Use Case:** Real-time feedback during throw

**Option B: MediaPipe Pose (BEST for ease of implementation)**
- **Pros:** 45+ FPS on iOS, easy integration, cross-platform, 33 keypoints
- **Cons:** Single-person limitation, struggles with multi-person
- **Use Case:** Consumer app, quick prototyping

**Option C: Apple Vision Framework (FALLBACK only)**
- **Pros:** Native iOS, 3D pose available
- **Cons:** Lowest accuracy (32.8 mAP), iOS-only, limited docs
- **Use Case:** Only if MediaPipe is too complex

#### Tier 2: Offline Analysis

**HRNet or MMPose**
- **Accuracy:** 77.0+ mAP (highest available)
- **Speed:** Slow (<12 FPS) but doesn't matter for offline
- **Use Case:** Post-throw detailed biomechanical analysis

#### Tier 3: Enhancements

- **Temporal smoothing** (Kalman filter, TCN, GCN)
- **Multi-camera 3D reconstruction**
- **Physics-based pose refinement**
- **Action classification** (throw phase detection)

---

## Apple Vision Framework Verdict

### Strengths
✅ Native iOS integration (no external dependencies)
✅ On-device processing (privacy, low latency)
✅ 3D pose available (iOS 17+)
✅ Optimized for Neural Engine

### Critical Weaknesses
❌ **32.8 mAP** - Significantly lower than MediaPipe (45.0 mAP)
❌ **No standard benchmarks** - No COCO/MPII results published
❌ **Unknown architecture** - Cannot customize or optimize
❌ **iOS-only** - Platform locked
❌ **Limited sports validation** - Designed for fitness, not athletics

### Should You Use It?

**❌ NO** for professional hammer throw analysis
- Accuracy too low compared to alternatives
- No proven track record for athletic movements
- MediaPipe performs better on same platform (iOS)

**⚠️ MAYBE** for simple consumer fitness features
- If you need native iOS integration only
- For basic technique feedback (not competition analysis)
- Must enhance with temporal filtering

**✅ YES** only if:
- You absolutely cannot use external frameworks
- 3D pose is critical requirement (iOS 17+)
- Accuracy requirements are minimal

---

## Implementation Recommendation

### Phase 1: Prototype (Week 1-2)
```
Framework: MediaPipe Pose
Platform: iOS
Features:
  - Basic real-time pose detection
  - 33 keypoint tracking
  - Simple visualization
  - Frame rate: 45+ FPS target
```

### Phase 2: Enhancement (Week 3-6)
```
Add:
  - Temporal smoothing (Kalman filter)
  - Action classification (throw phases)
  - Motion blur handling
  - High FPS video (120-240 FPS)
```

### Phase 3: Advanced Analysis (Week 7-10)
```
Add:
  - Offline HRNet processing
  - Multi-camera 3D reconstruction
  - Biomechanical analysis
  - Athlete-specific calibration
```

### Phase 4: Optimization (Week 11-12)
```
Options:
  A. Switch to YOLOv8-Pose for better fast-motion handling
  B. Fine-tune models on hammer throw dataset
  C. Deploy hybrid system (MediaPipe live + HRNet offline)
```

---

## Key Performance Targets

### Minimum Requirements
| Metric | Target | Why |
|--------|--------|-----|
| FPS | 30+ | Smooth real-time feedback |
| Latency | <100ms | Acceptable for live coaching |
| Detection Rate | 90%+ | Reliable keypoint tracking |
| Positional Error | <5px | Accurate joint localization |

### Ideal Performance
| Metric | Target | Why |
|--------|--------|-----|
| FPS | 60+ | Silky smooth motion |
| Latency | <50ms | Instantaneous feedback |
| Detection Rate | 95%+ | Very reliable tracking |
| Positional Error | <3px | High-precision analysis |
| Temporal Stability | No jitter | Smooth trajectories |

---

## Cost-Benefit Analysis

### Apple Vision Framework
**Cost:** $0 (included in iOS)
**Development Time:** Low (1-2 weeks)
**Performance:** Moderate (32.8 mAP, ~30-60 FPS)
**Limitation:** Platform locked, low accuracy
**Verdict:** ⚠️ Not recommended unless forced constraint

### MediaPipe Pose
**Cost:** $0 (open source)
**Development Time:** Low (1-2 weeks)
**Performance:** Good (45.0 mAP, 45+ FPS)
**Limitation:** Single-person focus
**Verdict:** ✅ Best starting point

### YOLOv8-Pose
**Cost:** $0 (open source)
**Development Time:** Moderate (2-4 weeks, CoreML conversion)
**Performance:** Best for sports (~65-70 mAP, 33-36 FPS)
**Limitation:** Setup complexity
**Verdict:** ✅ Best for production (fast movements)

### HRNet/MMPose
**Cost:** $0 (open source)
**Development Time:** Moderate (2-3 weeks)
**Performance:** Highest accuracy (77.0 mAP, <12 FPS)
**Limitation:** Not real-time
**Verdict:** ✅ Essential for offline analysis

---

## Final Answer: Which Model to Use?

```
FOR HAMMERTRACK:

Real-Time (choose one):
  1st choice: YOLOv8-Pose (best for fast movements)
  2nd choice: MediaPipe (easiest implementation)
  3rd choice: Apple Vision (only if forced to use native)

Offline Analysis:
  1st choice: HRNet (highest accuracy)
  2nd choice: MMPose (flexible, modular)

Enhancements (add to any model):
  - Temporal Convolutional Network (TCN)
  - Multi-camera 3D reconstruction
  - Physics-based optimization
  - Athlete-specific fine-tuning
```

**Start with MediaPipe, enhance with temporal filtering, add HRNet for offline analysis. Consider upgrading to YOLOv8-Pose if fast movement tracking is insufficient.**

