// Zusätzliche Konfigurationsoptionen für HammerTracker

// In HammerTracker.swift, füge diese Eigenschaften zur Klasse hinzu:

// MARK: - Konfigurierbare Parameter für robuste Erkennung
struct TrackingConfiguration {
    // Minimum Prominenz als Faktor der Amplitude (0.0 - 1.0)
    var minProminenceFactor: Double = 0.15
    
    // Minimum Bewegungsschwelle als Faktor der Amplitude
    var minMovementFactor: Double = 0.03
    
    // Glättungsfenstergröße (ungerade Zahl)
    var smoothingWindowSize: Int = 5
    
    // Erwartete Umkehrpunkte pro Sekunde (für Validierung)
    var expectedTurningPointsPerSecond: Double = 2.0
    
    // Maximale erlaubte Abweichung von erwarteter Anzahl (als Faktor)
    var maxDeviationFactor: Double = 0.5
    
    // Ob Fallback auf alte Methode erlaubt ist
    var allowFallback: Bool = true
    
    // Minimum Frames zwischen Umkehrpunkten
    var minFramesBetweenTurns: Int = 10
}

// Verwendung in der App:
// hammerTracker.trackingConfig.minProminenceFactor = 0.2  // Strengere Filterung
// hammerTracker.trackingConfig.smoothingWindowSize = 7    // Stärkere Glättung

// Alternative: Frequenzbasierte Methode für sehr regelmäßige Bewegungen
extension HammerTracker {
    
    // Diese Methode kann verwendet werden, wenn die Bewegung sehr regelmäßig ist
    func analyzeTrajectoryWithExpectedFrequency(expectedSwingsPerSecond: Double) -> TrajectoryAnalysis? {
        guard trackedFrames.count > 20 else { return nil }
        
        let frameRate: Double = 30.0 // Annahme: 30 FPS
        let expectedFramesPerSwing = frameRate / expectedSwingsPerSecond
        let expectedTurningPoints = Int(Double(trackedFrames.count) / expectedFramesPerSwing * 2)
        
        // Finde genau N Umkehrpunkte
        let turningPoints = findTopNTurningPoints(n: expectedTurningPoints)
        
        // Rest der Analyse wie gehabt...
        let ellipses = createEllipsesFromThreePoints(from: turningPoints)
        let analyzedEllipses = Array(ellipses.dropFirst(2))
        
        guard !analyzedEllipses.isEmpty else { return nil }
        
        let averageAngle = analyzedEllipses.reduce(0.0) { $0 + $1.angle } / Double(analyzedEllipses.count)
        
        return TrajectoryAnalysis(
            ellipses: analyzedEllipses,
            totalFrames: trackedFrames.count,
            averageAngle: averageAngle
        )
    }
    
    private func findTopNTurningPoints(n: Int) -> [TurningPoint] {
        let smoothedPoints = smoothTrajectoryForAnalysis()
        guard smoothedPoints.count > 15 else { return [] }
        
        struct PeakCandidate {
            let frameIndex: Int
            let point: CGPoint
            let prominence: CGFloat
            let isMaximum: Bool
        }
        
        var candidates: [PeakCandidate] = []
        
        // Finde alle lokalen Extrema
        for i in 1..<(smoothedPoints.count - 1) {
            let prev = smoothedPoints[i-1].x
            let curr = smoothedPoints[i].x
            let next = smoothedPoints[i+1].x
            
            if curr > prev + 0.001 && curr > next + 0.001 {
                let prominence = calculateProminence(at: i, in: smoothedPoints, isMaximum: true)
                candidates.append(PeakCandidate(
                    frameIndex: i,
                    point: CGPoint(x: curr, y: smoothedPoints[i].y),
                    prominence: prominence,
                    isMaximum: true
                ))
            } else if curr < prev - 0.001 && curr < next - 0.001 {
                let prominence = calculateProminence(at: i, in: smoothedPoints, isMaximum: false)
                candidates.append(PeakCandidate(
                    frameIndex: i,
                    point: CGPoint(x: curr, y: smoothedPoints[i].y),
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
            let mappedFrameIndex = min(candidate.frameIndex * trackedFrames.count / smoothedPoints.count, trackedFrames.count - 1)
            return TurningPoint(
                frameIndex: mappedFrameIndex,
                point: candidate.point,
                isMaximum: candidate.isMaximum
            )
        }
    }
    
    private func calculateProminence(at index: Int, in points: [(x: CGFloat, y: CGFloat)], isMaximum: Bool) -> CGFloat {
        let peakValue = points[index].x
        
        // Finde die tiefsten/höchsten Punkte links und rechts
        var leftBound = peakValue
        var rightBound = peakValue
        
        // Suche links
        for i in stride(from: index - 1, through: 0, by: -1) {
            if isMaximum {
                leftBound = min(leftBound, points[i].x)
            } else {
                leftBound = max(leftBound, points[i].x)
            }
        }
        
        // Suche rechts
        for i in (index + 1)..<points.count {
            if isMaximum {
                rightBound = min(rightBound, points[i].x)
            } else {
                rightBound = max(rightBound, points[i].x)
            }
        }
        
        // Prominenz ist die Differenz zum höheren/niedrigeren der beiden Bounds
        if isMaximum {
            return peakValue - max(leftBound, rightBound)
        } else {
            return min(leftBound, rightBound) - peakValue
        }
    }
}
