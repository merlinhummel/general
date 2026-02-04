# HammerTrack: Federungs-Logik Implementation

## Zusammenfassung der Änderungen

### Problem
Die ursprüngliche Ellipsen-Erkennung verwendete komplexe Schwellwerte und Heuristiken, die zu falschen Umkehrpunkten führten:
- `minMovementThreshold = 0.015`
- `minFramesBetweenTurns = 15`
- Nur 3 Ellipsen erkannt statt 12

### Lösung: Reine Federungs-Logik
**Konzept:** Wie eine Feder von der Seite betrachtet
- Fokus nur auf X-Achse
- Richtungsänderung = Umkehrpunkt
- Keine Schwellwerte
- Keine Heuristiken

## Implementierte Änderungen

### 1. Python-Analyse (`correct_spring_analysis.py`)
**Schritt-für-Schritt-Algorithmus:**

```python
# SCHRITT 1: Erster Punkt = TP0
turning_points.append(data_points[0])

# SCHRITT 2: Initiale Richtung
for dx in data_points:
    if dx != 0:
        current_direction = 1 if dx > 0 else -1
        break

# SCHRITT 3: Alle Richtungsänderungen
for dx in data_points:
    if dx != 0:
        new_direction = 1 if dx > 0 else -1
        if new_direction != current_direction:
            turning_points.append(point)  # Umkehrpunkt!
            current_direction = new_direction

# SCHRITT 4: Konsekutive Ellipsen
for i in range(len(turning_points) - 1):
    ellipse = create_ellipse(turning_points[i], turning_points[i+1])
```

**Ergebnis:**
- 13 Umkehrpunkte gefunden
- 12 Ellipsen erstellt
- Durchschnittlicher Winkel: -1.89°

### 2. iOS Swift Code (`HammerTracker.swift`)

#### A) `findTurningPoints()` - Zeilen 559-638
**Entfernt:**
- ❌ `minMovementThreshold`
- ❌ `minFramesBetweenTurns`
- ❌ Frame-Gap Checks innerhalb der Schleife
- ❌ Zeitsprung-Checks

**Neu:**
```swift
// SCHRITT 1: Erster Punkt ist IMMER TP0
let firstPoint = CGPoint(x: trackedFrames[0].boundingBox.midX,
                         y: trackedFrames[0].boundingBox.midY)
turningPoints.append(TurningPoint(frameIndex: 0, point: firstPoint, isMaximum: false))

// SCHRITT 2: Initiale Richtung (JEDE Bewegung zählt!)
for i in 1..<trackedFrames.count {
    let dx = trackedFrames[i].boundingBox.midX - trackedFrames[i-1].boundingBox.midX
    if dx != 0 {
        currentDirection = dx > 0 ? 1 : -1
        break
    }
}

// SCHRITT 3: Alle Richtungsänderungen finden
for i in 1..<trackedFrames.count {
    let dx = trackedFrames[i].boundingBox.midX - trackedFrames[i-1].boundingBox.midX

    if dx != 0 {
        let newDirection = dx > 0 ? 1 : -1

        if newDirection != currentDirection {
            // Umkehrpunkt gefunden!
            turningPoints.append(TurningPoint(...))
            currentDirection = newDirection
        }
    }
}
```

#### B) `createEllipses()` - Zeilen 640-691
**Vorher:**
```swift
for i in stride(from: 0, to: turningPoints.count - 1, by: 2) {
    // Erstellt nur jede 2. Ellipse: (0,1), (2,3), (4,5), ...
}
```

**Nachher:**
```swift
// KONSEKUTIVE PAARE - Jeder Umkehrpunkt ist Ende UND Start!
for i in 0..<(turningPoints.count - 1) {
    let startPoint = turningPoints[i]
    let endPoint = turningPoints[i + 1]

    // Ellipse 1: TP0 → TP1
    // Ellipse 2: TP1 → TP2 (TP1 ist Ende von E1 UND Start von E2!)
    // Ellipse 3: TP2 → TP3
    // ...
}
```

## Testergebnisse

### Python-Visualisierung
**Datei:** `correct_spring_analysis.png`

**Ausgabe:**
```
📊 SCHRITT 1: 112 Punkte eingelesen
🎯 SCHRITT 2: TP0 (START): Frame 0
🧭 SCHRITT 3: Initiale Richtung: LINKS ← bei Frame 2
🔄 SCHRITT 4: 13 Umkehrpunkte gefunden

📐 SCHRITT 5: 12 Ellipsen erstellt:
  Ellipse 1: -24.44°
  Ellipse 2: 20.51°
  Ellipse 3: -19.30°
  Ellipse 4: 14.13°
  Ellipse 5: -10.57°
  Ellipse 6: 3.75°
  Ellipse 7: -2.92°
  Ellipse 8: -0.70°
  Ellipse 9: 1.96°
  Ellipse 10: -3.03°
  Ellipse 11: 4.81°
  Ellipse 12: -6.89°

Durchschnitt: -1.89°
```

### iOS Build
```
** BUILD SUCCEEDED **
```

## Wichtige Prinzipien

### 1. Reine X-Achsen-Betrachtung
- Y-Achse nur für Winkelberechnung
- Umkehrpunkte basieren NUR auf X-Richtungsänderung

### 2. Keine Schwellwerte
- Jede Bewegung zählt
- Keine minimale Distanz
- Keine minimalen Frames zwischen Umkehrpunkten

### 3. Konsekutive Ellipsen
- Jeder Umkehrpunkt ist gleichzeitig Ende UND Start
- Keine Lücken zwischen Ellipsen
- Ellipse N+1 startet wo Ellipse N endet

### 4. Winkelberechnung
```swift
let dx = endPoint.x - startPoint.x
let dy = endPoint.y - startPoint.y
let angleRad = atan2(abs(dy), abs(dx))
let angleDeg = angleRad * 180.0 / .pi

// Y=0 ist oben!
if startPoint.y > endPoint.y {
    return angleDeg  // Fällt nach oben → positiv
} else {
    return -angleDeg  // Fällt nach unten → negativ
}
```

## Nächste Schritte

1. ✅ Python-Algorithmus implementiert
2. ✅ iOS Swift Code aktualisiert
3. ✅ Build erfolgreich
4. ⏳ Test mit echtem Video auf iOS-Gerät
5. ⏳ Vergleich der iOS-Logs mit Python-Ergebnissen

## Dateien

### Neu/Aktualisiert
- ✅ `/Users/merlinhummel/Documents/HammerTrack/correct_spring_analysis.py`
- ✅ `/Users/merlinhummel/Documents/HammerTrack/correct_spring_analysis.png`
- ✅ `/Users/merlinhummel/Documents/HammerTrack/HammerTrack/Services/HammerTracker.swift`

### Alt (zum Vergleich)
- ❌ `final_correct_analysis.py` (verwendet iOS-Log Umkehrpunkte)
- ❌ `analyze_correct_ellipses.py` (3-Punkt-Überlappung)
- ❌ `spring_ellipses.png` (alte Visualisierung)

## Technische Details

### Frame-Gap Regel
Die 10-Frame-Gap-Regel bleibt in `detectHammer()` aktiv (Zeile 183-186), wird aber NICHT mehr in `findTurningPoints()` geprüft.

### Koordinatensystem
- X-Achse: 0 (links) bis 1 (rechts)
- Y-Achse: 0 (oben) bis 1 (unten) - nach Y-Flip für Visualisierung

### Video-Orientierung
- Portrait-Videos: 90° CW Rotation (Orientierung 6)
- Vision gibt normalisierte Koordinaten
