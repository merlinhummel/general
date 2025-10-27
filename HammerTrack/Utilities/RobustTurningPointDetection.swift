// MARK: - Robust Turning Points Detection
private func findTurningPointsRobust() -> [TurningPoint] {
    guard trackedFrames.count > 15 else { return [] }
    
    // 1. Erst die Trajektorie glätten, um Rauschen zu reduzieren
    let smoothedTrajectory = smoothTrajectoryForAnalysis()
    
    var turningPoints: [TurningPoint] = []
    var peakCandidates: [(frameIndex: Int, x: CGFloat, y: CGFloat, type: String)] = []
    
    // 2. Adaptive Parameter basierend auf der Bewegungsamplitude
    let xValues = smoothedTrajectory.map { $0.x }
    let amplitude = xValues.max()! - xValues.min()!
    
    // Dynamische Schwellwerte basierend auf der Amplitude
    let minMovementThreshold = max(0.01, amplitude * 0.03) // 3% der Amplitude
    let minProminence = amplitude * 0.15 // Ein Umkehrpunkt muss mindestens 15% der Amplitude prominent sein
    
    print("Amplitude: \(amplitude), Movement Threshold: \(minMovementThreshold), Prominence: \(minProminence)")
    
    // 3. Finde alle lokalen Maxima und Minima
    for i in 1..<(smoothedTrajectory.count - 1) {
        let prev = smoothedTrajectory[i-1].x
        let curr = smoothedTrajectory[i].x
        let next = smoothedTrajectory[i+1].x
        
        // Lokales Maximum
        if curr > prev && curr > next {
            peakCandidates.append((
                frameIndex: i,
                x: curr,
                y: smoothedTrajectory[i].y,
                type: "Maximum"
            ))
        }
        // Lokales Minimum
        else if curr < prev && curr < next {
            peakCandidates.append((
                frameIndex: i,
                x: curr,
                y: smoothedTrajectory[i].y,
                type: "Minimum"
            ))
        }
    }
    
    // 4. Filtere Kandidaten nach Prominenz
    var filteredCandidates: [(frameIndex: Int, x: CGFloat, y: CGFloat, type: String)] = []
    
    for i in 0..<peakCandidates.count {
        let candidate = peakCandidates[i]
        var isProminent = false
        
        if candidate.type == "Maximum" {
            // Finde die nächsten Minima links und rechts
            var leftMin: CGFloat = candidate.x
            var rightMin: CGFloat = candidate.x
            
            // Suche links
            for j in stride(from: i-1, through: 0, by: -1) {
                if peakCandidates[j].type == "Minimum" {
                    leftMin = peakCandidates[j].x
                    break
                }
            }
            
            // Suche rechts
            for j in (i+1)..<peakCandidates.count {
                if peakCandidates[j].type == "Minimum" {
                    rightMin = peakCandidates[j].x
                    break
                }
            }
            
            let prominence = candidate.x - max(leftMin, rightMin)
            isProminent = prominence >= minProminence
            
        } else { // Minimum
            // Finde die nächsten Maxima links und rechts
            var leftMax: CGFloat = candidate.x
            var rightMax: CGFloat = candidate.x
            
            // Suche links
            for j in stride(from: i-1, through: 0, by: -1) {
                if peakCandidates[j].type == "Maximum" {
                    leftMax = peakCandidates[j].x
                    break
                }
            }
            
            // Suche rechts
            for j in (i+1)..<peakCandidates.count {
                if peakCandidates[j].type == "Maximum" {
                    rightMax = peakCandidates[j].x
                    break
                }
            }
            
            let prominence = min(leftMax, rightMax) - candidate.x
            isProminent = prominence >= minProminence
        }
        
        if isProminent {
            filteredCandidates.append(candidate)
        }
    }
    
    // 5. Stelle sicher, dass Maxima und Minima alternieren
    var finalCandidates: [(frameIndex: Int, x: CGFloat, y: CGFloat, type: String)] = []
    var lastType: String? = nil
    
    for candidate in filteredCandidates {
        if lastType == nil || candidate.type != lastType {
            finalCandidates.append(candidate)
            lastType = candidate.type
        } else {
            // Wenn zwei vom gleichen Typ aufeinander folgen, behalte den prominenteren
            if let last = finalCandidates.last {
                if candidate.type == "Maximum" && candidate.x > last.x {
                    finalCandidates[finalCandidates.count - 1] = candidate
                } else if candidate.type == "Minimum" && candidate.x < last.x {
                    finalCandidates[finalCandidates.count - 1] = candidate
                }
            }
        }
    }
    
    // 6. Konvertiere zu TurningPoints
    for (index, candidate) in finalCandidates.enumerated() {
        let originalFrameIndex = trackedFrames.firstIndex { frame in
            abs(frame.boundingBox.midX - candidate.x) < 0.001 &&
            abs(frame.boundingBox.midY - candidate.y) < 0.001
        } ?? candidate.frameIndex
        
        turningPoints.append(TurningPoint(
            frameIndex: originalFrameIndex,
            point: CGPoint(x: candidate.x, y: candidate.y),
            isMaximum: candidate.type == "Maximum"
        ))
    }
    
    // 7. Validierung: Stelle sicher, dass wir mindestens 3 Umkehrpunkte haben
    if turningPoints.count < 3 {
        print("Warnung: Nur \(turningPoints.count) Umkehrpunkte gefunden. Fallback auf alte Methode.")
        return findTurningPoints() // Fallback auf die alte Methode
    }
    
    // 8. Qualitätskontrolle: Prüfe ob die Anzahl der Umkehrpunkte plausibel ist
    let videoDuration = trackedFrames.last?.timestamp ?? 0
    let expectedTurningPoints = Int(videoDuration * 2) // ~2 Umkehrpunkte pro Sekunde als Richtwert
    
    if abs(turningPoints.count - expectedTurningPoints) > expectedTurningPoints / 2 {
        print("Warnung: Ungewöhnliche Anzahl von Umkehrpunkten: \(turningPoints.count) (erwartet: ~\(expectedTurningPoints))")
    }
    
    print("=== Robuste Umkehrpunkt-Erkennung ===")
    print("Gefunden: \(turningPoints.count) Umkehrpunkte")
    print("Amplitude: \(String(format: "%.3f", amplitude))")
    print("Verwendet: Movement Threshold = \(String(format: "%.3f", minMovementThreshold)), Prominence = \(String(format: "%.3f", minProminence))")
    
    return turningPoints
}

// Hilfsfunktion: Glättung der Trajektorie für die Analyse
private func smoothTrajectoryForAnalysis() -> [(x: CGFloat, y: CGFloat)] {
    guard let trajectory = currentTrajectory else { return [] }
    
    // Stärkere Glättung für die Umkehrpunkt-Erkennung
    let points = trajectory.points
    let smoothingWindow = 5 // Glättungsfenster
    
    var smoothed: [(x: CGFloat, y: CGFloat)] = []
    
    for i in 0..<points.count {
        var sumX: CGFloat = 0
        var sumY: CGFloat = 0
        var count = 0
        
        for j in max(0, i - smoothingWindow)...min(points.count - 1, i + smoothingWindow) {
            sumX += points[j].x
            sumY += points[j].y
            count += 1
        }
        
        smoothed.append((
            x: sumX / CGFloat(count),
            y: sumY / CGFloat(count)
        ))
    }
    
    return smoothed
}

// MARK: - Alternative: Frequenzbasierte Erkennung
private func findTurningPointsFrequencyBased() -> [TurningPoint] {
    guard trackedFrames.count > 30 else { return [] }
    
    // Extrahiere X-Positionen
    let xPositions = trackedFrames.map { $0.boundingBox.midX }
    
    // 1. Schätze die Frequenz der Schwingung
    let frequency = estimateSwingFrequency(xPositions: xPositions)
    print("Geschätzte Frequenz: \(frequency) Schwingungen pro Frame")
    
    // 2. Erwartete Anzahl von Umkehrpunkten
    let expectedPeaks = Int(Double(trackedFrames.count) * frequency * 2) // 2 Umkehrpunkte pro Schwingung
    
    // 3. Finde die N prominentesten Umkehrpunkte
    return findTopNTurningPoints(n: expectedPeaks, xPositions: xPositions)
}

// Hilfsfunktion: Frequenzschätzung mittels Zero-Crossing
private func estimateSwingFrequency(xPositions: [CGFloat]) -> Double {
    guard xPositions.count > 10 else { return 0.0 }
    
    // Berechne den Mittelwert
    let mean = xPositions.reduce(0, +) / CGFloat(xPositions.count)
    
    // Zähle Zero-Crossings (Durchgänge durch den Mittelwert)
    var crossings = 0
    var lastSign: Int? = nil
    
    for x in xPositions {
        let currentSign = x > mean ? 1 : -1
        if let last = lastSign, last != currentSign {
            crossings += 1
        }
        lastSign = currentSign
    }
    
    // Frequenz = Anzahl der Crossings / (2 * Anzahl der Frames)
    return Double(crossings) / (2.0 * Double(xPositions.count))
}

// Hilfsfunktion: Finde die N prominentesten Umkehrpunkte
private func findTopNTurningPoints(n: Int, xPositions: [CGFloat]) -> [TurningPoint] {
    struct PeakCandidate {
        let frameIndex: Int
        let x: CGFloat
        let prominence: CGFloat
        let isMaximum: Bool
    }
    
    var candidates: [PeakCandidate] = []
    
    // Finde alle lokalen Extrema mit ihrer Prominenz
    for i in 1..<(xPositions.count - 1) {
        let prev = xPositions[i-1]
        let curr = xPositions[i]
        let next = xPositions[i+1]
        
        if curr > prev && curr > next {
            // Maximum gefunden
            let prominence = calculateProminence(at: i, in: xPositions, isMaximum: true)
            candidates.append(PeakCandidate(
                frameIndex: i,
                x: curr,
                prominence: prominence,
                isMaximum: true
            ))
        } else if curr < prev && curr < next {
            // Minimum gefunden
            let prominence = calculateProminence(at: i, in: xPositions, isMaximum: false)
            candidates.append(PeakCandidate(
                frameIndex: i,
                x: curr,
                prominence: prominence,
                isMaximum: false
            ))
        }
    }
    
    // Sortiere nach Prominenz und wähle die Top N
    candidates.sort { $0.prominence > $1.prominence }
    let topCandidates = Array(candidates.prefix(n))
    
    // Sortiere nach Frame-Index für chronologische Reihenfolge
    let sortedCandidates = topCandidates.sorted { $0.frameIndex < $1.frameIndex }
    
    // Konvertiere zu TurningPoints
    return sortedCandidates.map { candidate in
        TurningPoint(
            frameIndex: candidate.frameIndex,
            point: CGPoint(
                x: trackedFrames[candidate.frameIndex].boundingBox.midX,
                y: trackedFrames[candidate.frameIndex].boundingBox.midY
            ),
            isMaximum: candidate.isMaximum
        )
    }
}

// Hilfsfunktion: Berechne die Prominenz eines Peaks
private func calculateProminence(at index: Int, in values: [CGFloat], isMaximum: Bool) -> CGFloat {
    let peakValue = values[index]
    
    // Finde die tiefsten/höchsten Punkte links und rechts
    var leftBound = peakValue
    var rightBound = peakValue
    
    // Suche links
    for i in stride(from: index - 1, through: 0, by: -1) {
        if isMaximum {
            leftBound = min(leftBound, values[i])
        } else {
            leftBound = max(leftBound, values[i])
        }
    }
    
    // Suche rechts
    for i in (index + 1)..<values.count {
        if isMaximum {
            rightBound = min(rightBound, values[i])
        } else {
            rightBound = max(rightBound, values[i])
        }
    }
    
    // Prominenz ist die Differenz zum höheren/niedrigeren der beiden Bounds
    if isMaximum {
        return peakValue - max(leftBound, rightBound)
    } else {
        return min(leftBound, rightBound) - peakValue
    }
}