# Compare View - Fehleranalyse

## 🐛 Identifizierte Probleme

### 1. ❌ Kritisch: `.id()` Modifier führt zu falscher Video-Zuordnung

**Location:** CompareView.swift Lines 64, 111

**Problem:**
```swift
ZoomableVideoView(player: player1, ...)
    .id(selectedVideoURLs.first)  // ❌ FALSCH!

ZoomableVideoView(player: player2, ...)
    .id(selectedVideoURLs.last)   // ❌ FALSCH!
```

**Warum ist das falsch?**
- Wenn Videos getauscht werden: `[videoA, videoB]` → `[videoB, videoA]`
- `.first` ändert sich von videoA zu videoB
- SwiftUI erstellt neue View wegen `.id()` Änderung
- ABER: `player1` zeigt immer noch videoA!
- **Result:** View wird neu erstellt, aber mit falschem Player → Positionierungsfehler

**Fix:**
- `.id()` muss mit dem PLAYER synchronisiert sein, nicht mit der Array-Position
- Lösung: Verwende `player1.currentItem?.asset` als eindeutige ID

---

### 2. ❌ Kritisch: Video-Skalierung ignoriert Container-Höhe

**Location:** ZoomableVideoView.swift Lines 191-223

**Problem:**
```swift
// Berechne FIT nach BREITE (Video immer volle Breite)
let fitScale = bounds.width / videoSize.width
```

**Warum ist das falsch für Compare View?**

**Beispiel 1: Hochformat-Video (1080x1920) in Compare View**
- Container: 390px breit × 400px hoch (halber Bildschirm)
- fitScale = 390 / 1080 = 0.361
- Skalierte Höhe = 1920 × 0.361 = **693px**
- **Problem:** Video ist 693px hoch, aber Container nur 400px → Video zu groß!

**Beispiel 2: Querformat-Video (1920x1080) in Compare View**
- Container: 390px breit × 400px hoch
- fitScale = 390 / 1920 = 0.203
- Skalierte Höhe = 1080 × 0.203 = **219px**
- ✅ OK: Video passt in Container

**Beispiel 3: Mix - Querformat oben, Hochformat unten**
- Oberes Video: 219px hoch (passt)
- Unteres Video: 693px hoch (zu groß!)
- **Result:** Unteres Video wird abgeschnitten und falsch positioniert

**Fix:**
- Skalierung muss nach "aspect fit" funktionieren: MIN(widthScale, heightScale)
- Video soll IMMER komplett in Container passen
- In Compare View: Jedes Video bekommt maximal die halbe Bildschirmhöhe

---

### 3. ⚠️ Scroll funktioniert nicht richtig im oberen Video

**Location:** ZoomableVideoView.swift + CompareView.swift

**Mögliche Ursachen:**
1. VStack in CompareView verhindert Touch-Propagation
2. Beide ScrollViews konkurrieren um Touch-Events
3. `.frame(maxHeight: .infinity)` führt zu falscher Größenberechnung

**Fix:**
- Explizite Höhe für jeden Video-Container
- Separate GeometryReader für jeden Video-Container

---

## 🔧 Lösungsansätze

### Fix 1: Eindeutige Player-IDs

```swift
// CompareView.swift
@State private var playerID1: UUID = UUID()
@State private var playerID2: UUID = UUID()

// Bei Video-Wechsel:
playerID1 = UUID()
playerID2 = UUID()

// In View:
ZoomableVideoView(player: player1, ...)
    .id(playerID1)  // ✅ Unique per player

ZoomableVideoView(player: player2, ...)
    .id(playerID2)  // ✅ Unique per player
```

### Fix 2: Aspect Fit Skalierung

```swift
// ZoomableVideoView.swift - updateLayout()

// Berechne Skalierung für ASPECT FIT (Video passt immer in Container)
let widthScale = bounds.width / videoSize.width
let heightScale = bounds.height / videoSize.height
let fitScale = min(widthScale, heightScale)  // ✅ Nimm die kleinere Skalierung

// Video-Container in FIT Größe
let scaledSize = CGSize(
    width: videoSize.width * fitScale,
    height: videoSize.height * fitScale
)
```

### Fix 3: Explizite Container-Höhen

```swift
// CompareView.swift
GeometryReader { geometry in
    VStack(spacing: 0) {
        // Video 1 - Explizite Höhe
        ZoomableVideoView(player: player1, ...)
            .frame(height: geometry.size.height / 2)
            .id(playerID1)

        // Video 2 - Explizite Höhe
        ZoomableVideoView(player: player2, ...)
            .frame(height: geometry.size.height / 2)
            .id(playerID2)
    }
}
```

---

## 📋 Test-Szenarien

1. **Querformat + Querformat:** Beide 1920x1080
   - Erwartung: Beide Videos gleich groß, vertikal zentriert

2. **Hochformat + Hochformat:** Beide 1080x1920
   - Erwartung: Beide Videos gleich groß, horizontal zentriert (schwarze Ränder links/rechts)

3. **Querformat + Hochformat:** 1920x1080 + 1080x1920
   - Erwartung: Beide Videos passen in ihre Container, unterschiedliche Größen OK

4. **Videos tauschen:** Von [A, B] zu [B, A]
   - Erwartung: Videos werden korrekt neu zugeordnet, keine Positionierungsfehler

5. **Zoom im oberen Video:**
   - Erwartung: Vertikal und horizontal scrollbar ohne Probleme

---

## ⚡ Implementierung

Die Fixes müssen in dieser Reihenfolge implementiert werden:

1. **PlayerID Fix** in CompareView.swift (verhindert falsche Zuordnung)
2. **Aspect Fit Skalierung** in ZoomableVideoView.swift (korrekte Video-Größe)
3. **Explizite Container-Höhen** in CompareView.swift (separierte Scroll-Bereiche)
