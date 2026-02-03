# Zoom State Problem - Detaillierte Analyse

## 🔍 Problem-Beschreibung

**User-Report**: "Der Fehler tritt auf wenn in compare oder single view schon analysiert wurde und im gleichen Lauf dann nochmal in der gleichen oder anderen Funktion analysiert wird. Hier sind dann die zoom einstellung ganz komisch."

## 📊 Szenario-Analyse

### ✅ Funktioniert (Neue Videos):
1. User wählt Video A + B aus
2. Videos werden analysiert
3. User zoomt
4. User wählt Video C + D aus (NEUE URLs)
5. ✅ `selectedVideoURLs` ändert sich
6. ✅ `.id()` ändert sich → View wird NEU erstellt
7. ✅ Zoom startet bei 1.0x

### ❌ Problem (Re-Analyse gleicher Videos):
1. User wählt Video A + B aus
2. Videos werden analysiert
3. User zoomt Video (z.B. auf 3.0x)
4. User analysiert Video A + B NOCHMAL (ohne neue Auswahl)
5. ❌ `selectedVideoURLs` bleibt GLEICH
6. ❌ `.id()` ändert sich NICHT
7. ❌ View wird NICHT neu erstellt
8. ❌ Zoom bleibt bei 3.0x! (oder wird komisch)

## 🔬 Technische Ursache

### CompareView.swift Lifecycle

**onChange Handler (Zeile 331-335):**
```swift
.onChange(of: selectedVideoURLs) { _, urls in
    if urls.count == 2 {
        setupPlayers(with: urls)  // ← Nur bei URL-Änderung!
        processVideos(urls: urls)
    }
}
```

**Problem**: Wenn Videos nochmal analysiert werden **OHNE** neue Video-Auswahl:
- ❌ `onChange(of: selectedVideoURLs)` wird NICHT getriggert
- ❌ `setupPlayers()` wird NICHT aufgerufen
- ❌ Keine neuen AVPlayer Instanzen erstellt
- ❌ Bestehende Player werden wiederverwendet

### ZoomableVideoView.swift Player Detection

**updateUIView (Zeile 104-114):**
```swift
if playerLayer.player !== player {
    print("🔄 Updating player in playerLayer")
    playerLayer.player = player

    // Reset zoom state when player changes
    print("🔄 Resetting zoom state for new video")
    context.coordinator.currentZoomScale = 1.0
    context.coordinator.currentContentOffset = .zero
    scrollView?.setZoomScale(1.0, animated: false)
    scrollView?.setContentOffset(.zero, animated: false)
}
```

**Problem**: Bei Re-Analyse **OHNE** neue Player:
- `playerLayer.player === player` (gleiche Instanz!)
- ❌ Bedingung ist FALSE
- ❌ Zoom-Reset passiert NICHT

### View Identity (.id() Modifier)

**CompareView.swift (Zeile 64, 111):**
```swift
ZoomableVideoView(...)
    .id(selectedVideoURLs.first)  // ← Basiert nur auf URL!
```

**Problem**: Bei Re-Analyse:
- URLs bleiben gleich
- ❌ `.id()` ändert sich nicht
- ❌ View wird nicht neu erstellt
- ❌ Coordinator behält alten Zoom-Status

## 🎯 Mögliche Lösungen

### Option 1: UUID-basierte Player-IDs (⭐ Empfohlen)
```swift
@State private var playerID1: UUID = UUID()
@State private var playerID2: UUID = UUID()

// Bei JEDER Video-Analyse (auch Re-Analyse):
func startAnalysis() {
    playerID1 = UUID()  // Neue ID erzwingen
    playerID2 = UUID()
    processVideos()
}

ZoomableVideoView(...)
    .id(playerID1)  // ← Basiert auf expliziter ID
```

**Vorteile:**
- ✅ Funktioniert bei Re-Analyse
- ✅ Funktioniert bei Video-Swap
- ✅ Funktioniert bei gleichen Videos

### Option 2: Analysis-State Detection
```swift
@State private var analysisStartTime1: Date = Date()
@State private var analysisStartTime2: Date = Date()

// Bei Video Processing Start:
func processVideos(urls: [URL]) {
    analysisStartTime1 = Date()  // Trigger View Recreation
    analysisStartTime2 = Date()
    // ... processing
}

ZoomableVideoView(...)
    .id("\(selectedVideoURLs.first)-\(analysisStartTime1)")
```

### Option 3: Direct Zoom Reset in HammerTracker
```swift
// In HammerTracker.processVideo():
func processVideo(url: URL, completion: @escaping (Result<Trajectory, Error>) -> Void) {
    // Reset externe Zoom-State über Callback
    onAnalysisStart?()

    // ... processing
}
```

## 🔄 Aktueller Status

### Implementiert:
- ✅ `.id()` Modifier in CompareView (URLs-basiert)
- ✅ Player-Change Detection in ZoomableVideoView
- ✅ Zoom-Reset bei Player-Wechsel

### Fehlt:
- ❌ Zoom-Reset bei Re-Analyse OHNE neue Video-Auswahl
- ❌ Trigger für View-Recreation bei gleichen Videos

## ✅ Empfohlene Lösung

**Option 1 implementieren**: UUID-basierte Player-IDs mit Reset bei `processVideos()` Start:

```swift
// CompareView.swift
@State private var playerID1: UUID = UUID()
@State private var playerID2: UUID = UUID()

private func processVideos(urls: [URL]) {
    guard urls.count == 2 else { return }

    // ⚡ FORCE VIEW RECREATION bei jeder Analyse
    playerID1 = UUID()
    playerID2 = UUID()

    // ... rest of processing
}

// In body:
ZoomableVideoView(...)
    .id(playerID1)  // ✅ Unique per analysis
```

## 🧪 Test-Szenarien

1. ✅ Neue Videos auswählen → Zoom reset
2. ✅ Videos tauschen → Zoom reset
3. ❌ **Gleiche Videos nochmal analysieren → Zoom reset** ← AKTUELL BROKEN
4. ✅ Von Compare → Single View → Zoom reset
5. ✅ Von Single View → Compare → Zoom reset

## 📝 Zusammenfassung

**Root Cause**: View Identity (`.id()`) basiert nur auf `selectedVideoURLs`, die sich bei Re-Analyse nicht ändern.

**Impact**: Zoom-State bleibt erhalten wenn Videos nochmal analysiert werden ohne neue Video-Auswahl.

**Solution**: UUID-basierte Player-IDs die bei JEDEM `processVideos()` Call neu generiert werden.
