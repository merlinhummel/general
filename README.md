# HammerTrack

iOS-App zur Analyse von Hammerwurf-Bewegungen mit Computer Vision und Machine Learning.

## Projektstruktur

```
HammerTrack/
├── HammerTrack/                    # Hauptprojekt
│   ├── App/                        # App-Einstiegspunkt
│   │   └── Hammer_TrackApp.swift   # Main App Entry Point
│   │
│   ├── Views/                      # UI-Komponenten
│   │   ├── Screens/                # Haupt-Bildschirme
│   │   │   ├── ContentView.swift   # Home Screen
│   │   │   ├── LiveView.swift      # Live-Analyse
│   │   │   ├── SingleView.swift    # Einzelanalyse
│   │   │   ├── CompareView.swift   # Vergleichsansicht
│   │   │   └── CameraTestView.swift # Kamera-Test
│   │   │
│   │   └── Components/             # Wiederverwendbare UI-Komponenten
│   │       ├── TrajectoryView.swift
│   │       ├── SimpleTrajectoryView.swift
│   │       ├── TurningPointsOverlay.swift
│   │       ├── EllipseInfoView.swift
│   │       ├── ZoomableVideoView.swift
│   │       └── AnalysisOptionsView.swift
│   │
│   ├── ViewModels/                 # MVVM ViewModels (für zukünftige Verwendung)
│   │
│   ├── Models/                     # Datenmodelle (für zukünftige Verwendung)
│   │
│   ├── Services/                   # Business Logic & Services
│   │   ├── HammerTracker.swift     # Hammer-Tracking-Logik
│   │   └── PoseAnalyzer.swift      # Pose-Detection-Service
│   │
│   ├── Utilities/                  # Helper-Funktionen & Extensions
│   │   ├── RobustTurningPointDetection.swift
│   │   └── TrackingConfigurationOptions.swift
│   │
│   ├── Extensions/                 # Swift Extensions (für zukünftige Verwendung)
│   │
│   ├── Config/                     # Konfigurationsdateien
│   │   ├── ProjectConfiguration.swift
│   │   ├── ExportOptions.plist
│   │   └── Hammer-Track-Info.plist
│   │
│   └── Resources/                  # Assets & ML-Modelle
│       ├── Assets.xcassets/        # App Icons, Images
│       └── best.mlpackage/         # CoreML Model
│
├── HammerTrack.xcodeproj/          # Xcode Projektdatei
├── docs/                           # Dokumentation
│   ├── README.md
│   ├── AppStore_Metadata.md
│   ├── CHANGES_SUMMARY.md
│   └── IMPLEMENTED_FIXES.md
│
└── scripts/                        # Build & Deployment Scripts
    ├── build_for_appstore.sh
    ├── testflight_setup.sh
    └── generate_app_icons.py
```

## Features

- **Live-Analyse**: Echtzeit-Tracking von Hammerwurf-Bewegungen
- **Video-Analyse**: Frame-by-Frame Analyse von aufgenommenen Videos
- **Vergleichsansicht**: Vergleich von zwei Würfen nebeneinander
- **Pose Detection**: ML-basierte Körperhaltungserkennung
- **Trajektorien-Darstellung**: Visualisierung der Hammer-Flugbahn
- **Ellipsen-Berechnung**: Mathematische Analyse der Bewegungsmuster

## Technologien

- **SwiftUI**: Modernes UI-Framework
- **Vision Framework**: Computer Vision
- **CoreML**: Machine Learning Model Integration
- **AVFoundation**: Video-Verarbeitung
- **Combine**: Reactive Programming (geplant)

## Entwicklung

### Voraussetzungen
- Xcode 15+
- iOS 17+
- macOS 14+

### Build
```bash
open HammerTrack.xcodeproj
# Command+R zum Build & Run
```

### Scripts
```bash
# TestFlight Build
./scripts/testflight_setup.sh

# App Store Build
./scripts/build_for_appstore.sh

# Icons generieren
python3 scripts/generate_app_icons.py
```

## Architektur

Das Projekt folgt einer **MVVM-ähnlichen Architektur** mit klarer Trennung von:
- **Views**: UI-Präsentation
- **Services**: Business Logic
- **Utilities**: Helper-Funktionen
- **Resources**: Assets & ML-Modelle

## Lizenz

© 2024 Merlin Hummel. Alle Rechte vorbehalten.
