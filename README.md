# HammerTrack

Real-time hammer throw analysis for iOS — powered by on-device computer vision and machine learning.

![iOS](https://img.shields.io/badge/platform-iOS%2017%2B-000000?style=flat-square&logo=apple&logoColor=ffffff)
![Swift](https://img.shields.io/badge/language-Swift%205.9-F05138?style=flat-square&logo=swift&logoColor=ffffff)
![Xcode](https://img.shields.io/badge/Xcode-15%2B-007AFF?style=flat-square&logo=xcode&logoColor=ffffff)
![License](https://img.shields.io/badge/license-Proprietary-red?style=flat-square)

## Overview

HammerTrack provides frame-accurate biomechanical analysis of hammer throw movements. The app runs all inference entirely on-device using Apple's Neural Engine — no cloud dependency, no latency.

**Core capabilities:**
- Live real-time tracking at 60 FPS with adaptive multi-camera support
- Frame-by-frame video analysis with scrubbing and pose overlay
- Side-by-side throw comparison with synchronized playback
- Voice-based result readout (German TTS, hands-free)

## Tech Stack

| Area | Technology |
|---|---|
| UI | SwiftUI, Liquid Glass (iOS 26) |
| Computer Vision | Vision Framework (`VNDetectHumanBodyPoseRequest`) |
| Object Detection | CoreML + YOLO v11 nano (640×640, Neural Engine) |
| Camera | AVFoundation — adaptive multi-camera discovery |
| Audio | AVSpeechSynthesizer with voice caching & warmup |
| Performance | 60 FPS pipeline, frame throttling, concurrent queues |

## Architecture

```
HammerTrack/
├── App/                        # Entry point
│   └── Hammer_TrackApp.swift
├── Views/
│   ├── Screens/                # Top-level screens
│   │   ├── ContentView.swift   # Home / navigation
│   │   ├── LiveView.swift      # Live camera + real-time analysis
│   │   ├── SingleView.swift    # Single-video analysis
│   │   ├── CompareView.swift   # Side-by-side comparison
│   │   └── CameraTestView.swift
│   └── Components/             # Reusable UI
│       ├── TrajectoryView.swift
│       ├── SimpleTrajectoryView.swift
│       ├── TurningPointsOverlay.swift
│       ├── EllipseInfoView.swift
│       ├── ZoomableVideoView.swift
│       └── AnalysisOptionsView.swift
├── Services/                   # Core logic
│   ├── HammerTracker.swift     # Trajectory tracking & ellipse math
│   └── PoseAnalyzer.swift      # Pose keypoint extraction
├── Extensions/
│   └── LiquidGlassStyle.swift  # iOS 26 glassmorphism helpers
├── Config/                     # Build & runtime config
│   ├── ProjectConfiguration.swift
│   ├── Hammer-Track-Info.plist
│   └── ExportOptions.plist
└── Resources/
    ├── Assets.xcassets/        # Icons & colors
    └── *.mlpackage/            # CoreML models (nano, nano640)
```

**Design pattern:** Service-oriented with `ObservableObject` managers. `CameraManager` owns the entire `AVCaptureSession` lifecycle — discovery, format selection, device switching, and frame processing all run on dedicated serial/concurrent queues to avoid main-thread blocking.

## Key Engineering Decisions

- **On-device only.** All pose and object detection runs on the Neural Engine. Zero network calls during analysis.
- **Configure-before-add.** Camera format and frame rate are locked *before* the device is added to the capture session. This prevents the `-17281 FigCaptureSourceRemote` crash that occurs when AVFoundation tries to use an unconfigured input.
- **Adaptive camera discovery.** Uses `AVCaptureDevice.DiscoverySession` to map every available lens (Ultra Wide, Wide, Telephoto) to its native zoom factor at startup. Switching between them is a single device swap — no digital zoom involved.
- **TTS warmup.** A silent utterance is spoken at init to pre-load the speech engine. This eliminates the ~5-second first-speech delay on iOS.
- **Frame throttling.** Pose detection runs every frame during idle preview but drops to every 3rd frame during active hammer tracking, keeping the Neural Engine free for the YOLO detection pipeline.

## Setup

### Prerequisites

- Xcode 15.0+
- iOS 17.0+ deployment target
- macOS 14+ (Sonoma)
- Apple Silicon Mac recommended for Neural Engine simulator support

### Build & Run

```bash
open HammerTrack.xcodeproj
# Select target device → Command+R
```

### Scripts

```bash
./scripts/build_for_appstore.sh     # Archive for App Store
./scripts/testflight_setup.sh       # TestFlight build
python3 scripts/generate_app_icons.py  # Regenerate app icons
```

## Analysis Pipeline

```
Camera Frame (1080p @ 60 FPS)
        │
        ├──► Pose Detection (VNDetectHumanBodyPoseRequest)
        │         └──► Arm position → trigger tracking
        │
        ├──► Hammer Detection (YOLOv11 nano @ 640×640)
        │         └──► Bounding box → trajectory points
        │
        └──► HammerTracker
                  ├── Ellipse fitting per rotation
                  ├── Torso angle at turning points
                  └── TTS readout on completion
```

## ML Models

| Model | Input | Use case |
|---|---|---|
| `best.mlpackage` | 640×640 | Full-size detection (backup) |
| `bestnano.mlpackage` | 640×640 | Nano — fast inference |
| `bestnano640.mlpackage` | 640×640 | Production — Neural Engine optimised |

All models are YOLO v11 nano variants exported via Ultralytics → CoreML.

## License

© 2025 Merlin Hummel. All rights reserved.
