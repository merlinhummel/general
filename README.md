# HammerTrack

Eine iOS-App zur professionellen Analyse von Hammerwurf-Technik mit ML-basierter Bewegungserkennung.

## Überblick

HammerTrack nutzt maschinelles Lernen und Computer Vision, um die Bahn des Hammers in Videos zu verfolgen und detaillierte Analysen der Wurftechnik zu erstellen.

### Hauptfunktionen

- **Einzelanalyse**: Analysiere einzelne Würfe mit automatischer Ellipsen-Erkennung
- **Vergleichsanalyse**: Vergleiche zwei Würfe nebeneinander
- **Hammer-Bahn-Visualisierung**: Overlay der Hammer-Flugbahn über dem Video
- **Ellipsen-Winkel-Berechnung**: Automatische Berechnung von Neigungswinkeln
- **iOS 18 Liquid Glass Design**: Moderne glasmorphe Benutzeroberfläche

## Technologie-Stack

- **SwiftUI**: Moderne deklarative UI
- **AVFoundation**: Video-Processing
- **Core ML**: ML-Modell-Integration
- **Vision Framework**: Frame-Analyse
- **Combine**: Reaktive Programmierung

## Architektur

Das Projekt folgt dem MVVM-Pattern:

```
HammerTrack/
├── Models/              # Datenmodelle
│   ├── HammerData.swift
│   ├── Ellipse.swift
│   ├── ThrowAnalysis.swift
│   └── VideoMetadata.swift
├── ViewModels/          # Business Logic
│   ├── SingleAnalysisViewModel.swift
│   ├── ComparisonViewModel.swift
│   └── VideoProcessingViewModel.swift
├── Views/               # UI-Komponenten
│   ├── ContentView.swift
│   ├── SingleAnalysisView.swift
│   ├── ComparisonView.swift
│   └── Components/
├── Services/            # Service-Layer
│   ├── MLModelService.swift
│   ├── EllipseCalculator.swift
│   ├── VideoProcessor.swift
│   └── PathRenderer.swift
└── Resources/
```

## Algorithmus

### Ellipsen-Erkennung

Die App erkennt Ellipsen basierend auf Richtungswechseln der X-Koordinate:

1. Tracke Hammer-Position Frame-für-Frame
2. Erkenne Umkehrpunkte (X-Koordinaten-Richtungswechsel)
3. Eine Ellipse = Start → Umkehrpunkt → Ende
4. Berechne Neigungswinkel aus Höhendifferenz

### Hammer-Erkennung

- ML-Modell erkennt Hammer in jedem Frame
- Stopp-Kriterium: 5 aufeinanderfolgende Frames ohne Erkennung
- Confidence-Threshold: 0.5

## Requirements

- iOS 18.0+
- Xcode 15.0+
- Swift 5.9+

## ML-Modell Integration

Die App ist vorbereitet für die Integration eines Core ML Modells:

1. Trainiere ein Object Detection Modell für Hammer-Erkennung
2. Exportiere als `.mlmodel` Datei
3. Füge in `HammerTrack/Resources/` hinzu
4. Aktualisiere `MLModelService.swift` mit dem echten Modell

## Installation

1. Clone das Repository
2. Öffne `HammerTrack.xcodeproj` in Xcode
3. Wähle ein Entwicklungsteam in den Signing-Einstellungen
4. Build und Run auf iOS 18+ Gerät oder Simulator

## Features im Detail

### Einzelanalyse

- Video aus Galerie auswählen
- Automatische Hammer-Erkennung
- Ellipsen-Navigation (vorwärts/rückwärts)
- Interaktive Ellipsen-Auswahl
- Frame-by-Frame Scrubbing per Drag-Gesture
- Winkel-Anzeige pro Ellipse

### Vergleichsanalyse

- Zwei Videos nebeneinander
- Synchronisierte Navigation (optional)
- Vergleichsstatistiken
- Unabhängige oder gekoppelte Steuerung

### Liquid Glass Design

- Transluzente Material-Effekte
- Smooth Spring Animations
- Glasmorphismus-Buttons
- Modern iOS 18 Ästhetik

## Lizenz

Proprietär - Alle Rechte vorbehalten

## Version

1.0.0 - Initiales Release

---

Entwickelt mit Claude Code
