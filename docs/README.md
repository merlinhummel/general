# Hammer Track - iOS Trajectory Analysis App

## Überblick
Hammer Track ist eine iOS-App zur Analyse von Hammerwurf-Trajektorien mittels Computer Vision und Machine Learning. Die App erkennt automatisch einen Hammer in Videos und visualisiert dessen Flugbahn.

## Hauptfunktionen
- **Echtzeit-Hammerkennung**: Verwendet ein trainiertes CoreML-Modell zur Objekterkennung
- **Trajektorien-Visualisierung**: Zeichnet die Flugbahn des Hammers über das Video
- **Ellipsen-Analyse**: Erkennt und analysiert die elliptischen Bewegungsmuster
- **Video-Vergleich**: Vergleicht zwei Videos nebeneinander
- **Live-Kamera-Unterstützung**: Analyse in Echtzeit mit der Gerätekamera

## Technische Architektur

### Core ML Model
- **Datei**: `best.mlpackage`
- **Typ**: YOLO-basiertes Objekterkennungsmodell
- **Klasse**: Erkennt "Hammer" mit Konfidenzwerten
- **Input**: Video-Frames (CVPixelBuffer)
- **Output**: Bounding Boxes mit Koordinaten und Konfidenz

### Hauptkomponenten

#### HammerTracker.swift
Die zentrale Klasse für die Hammererkennung und Trajektorienanalyse:
- `processVideo(url:)`: Verarbeitet ein Video Frame für Frame
- `detectHammer(in:frameNumber:timestamp:)`: Führt die ML-Erkennung durch
- `analyzeTrajectory()`: Analysiert die Trajektorie und findet Ellipsen
- Verwendet VNCoreMLRequest für die Integration des ML-Modells

#### Views
1. **ContentView.swift**: Tab-basierte Navigation
2. **SingleView.swift**: Einzelvideo-Analyse
3. **CompareView.swift**: Vergleich zweier Videos
4. **LiveView.swift**: Echtzeit-Kameraanalyse
5. **ZoomableVideoView.swift**: Video-Player mit Zoom und Trajektorien-Overlay
6. **TrajectoryView.swift**: Zeichnet die Trajektorien-Pfade

### Koordinaten-Transformation
**Wichtig**: iOS-Videos sind oft um 90° gedreht. Die App kompensiert dies:
- Video-Orientierung wird erkannt (`.right` = 90° CW)
- Koordinaten werden in `ZoomableVideoView` transformiert
- Transformation: Für 90° CCW: `new_x = 1 - old_y, new_y = old_x`

## Setup für Entwickler

### Voraussetzungen
- Xcode 14.0+
- iOS 16.0+ Deployment Target
- Swift 5.0+

### Installation
1. Clone das Repository
2. Öffne `Hammer Track.xcodeproj` in Xcode
3. Stelle sicher, dass `best.mlpackage` im Projekt enthalten ist
4. Build und Run (Cmd+R)

### Projekt-Struktur
```
HammerTrack/
├── Hammer Track.xcodeproj/
├── Hammer Track/
│   ├── Assets.xcassets/
│   ├── best.mlpackage/          # ML Model
│   ├── Hammer_TrackApp.swift    # App Entry Point
│   ├── HammerTracker.swift      # Core Logic
│   ├── ContentView.swift        # Main Navigation
│   ├── SingleView.swift         # Single Video Analysis
│   ├── CompareView.swift        # Video Comparison
│   ├── LiveView.swift           # Live Camera
│   ├── ZoomableVideoView.swift  # Video Player
│   └── TrajectoryView.swift     # Trajectory Drawing
├── Hammer TrackTests/
└── Hammer TrackUITests/
```

## Bekannte Probleme & Lösungen

### 90° Video-Rotation
- **Problem**: Videos erscheinen um 90° gedreht
- **Lösung**: Koordinaten-Transformation in `ZoomableVideoView.swift`
- **Code**: Check `updateTrajectory()` Methode für Transformationslogik

### ML Model Loading
- **Problem**: "Unable to load MPSGraphExecutable" Warnings
- **Lösung**: Diese Warnings können ignoriert werden, das Model funktioniert trotzdem

### Performance
- **Tipp**: Confidence Threshold ist auf 0.3 gesetzt für bessere Erkennung
- **Optimierung**: Frame-Processing erfolgt asynchron auf `processingQueue`

## Debugging

### Nützliche Debug-Ausgaben
- Frame-Detection logs alle 30 Frames (1 Sekunde bei 30fps)
- Bounding Box Koordinaten werden geloggt
- Transformationen können in der Console verfolgt werden

### Test-Workflow
1. Wähle ein Video mit klarem Hammerwurf
2. Überprüfe Console für Detection-Logs
3. Verifiziere Trajektorien-Visualisierung
4. Teste Zoom und Pan Funktionalität

## Weiterentwicklung

### Mögliche Verbesserungen
1. **Multi-Object Tracking**: Mehrere Hämmer gleichzeitig verfolgen
2. **3D-Analyse**: Tiefenberechnung aus 2D-Trajektorien
3. **Export-Funktion**: Trajektorien-Daten als CSV/JSON exportieren
4. **Kalibrierung**: Reale Distanzen aus Video berechnen
5. **Slow-Motion Support**: Bessere Unterstützung für Hochgeschwindigkeitsvideos

### ML Model Training
- Das aktuelle Model wurde mit YOLO trainiert
- Für Verbesserungen: Mehr annotierte Trainingsvideos sammeln
- Dataset sollte verschiedene Lichtverhältnisse und Hintergründe enthalten

## Kontakt & Support
Bei Fragen oder Problemen erstelle ein Issue im GitHub Repository.
