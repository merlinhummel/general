import Foundation
import CoreML
import Vision
import AVFoundation
import UIKit
import CoreGraphics

// MARK: - Data Models
struct TrackedFrame {
    let frameNumber: Int      // Original video frame number
    let boundingBox: CGRect
    let confidence: Float
    let timestamp: TimeInterval
}

struct Trajectory {
    let frames: [TrackedFrame]
    let videoOrientation: CGImagePropertyOrientation
    let videoSize: CGSize // Actual display size after transformation
    
    init(frames: [TrackedFrame], videoOrientation: CGImagePropertyOrientation = .up, videoSize: CGSize = .zero) {
        self.frames = frames
        self.videoOrientation = videoOrientation
        self.videoSize = videoSize
    }
    
    var points: [CGPoint] {
        return frames.map { frame in
            CGPoint(x: frame.boundingBox.midX, y: frame.boundingBox.midY)
        }
    }
    
    // Improved smoothing using Savitzky-Golay filter or Gaussian smoothing
    var smoothedPoints: [CGPoint] {
        guard points.count > 5 else { return points }
        
        // Use Gaussian smoothing for better results with minimal change
        return gaussianSmooth(points: points, sigma: 0.5)  // Reduced from 1.5 to 0.5 for light smoothing
    }
    
    // Gaussian smoothing implementation
    private func gaussianSmooth(points: [CGPoint], sigma: Double) -> [CGPoint] {
        let windowSize = Int(ceil(sigma * 3)) * 2 + 1
        var smoothed: [CGPoint] = []
        
        // Create Gaussian kernel
        var kernel: [Double] = []
        let center = windowSize / 2
        var sum = 0.0
        
        for i in 0..<windowSize {
            let x = Double(i - center)
            let weight = exp(-(x * x) / (2 * sigma * sigma))
            kernel.append(weight)
            sum += weight
        }
        
        // Normalize kernel
        kernel = kernel.map { $0 / sum }
        
        // Apply convolution
        for i in 0..<points.count {
            var weightedX = 0.0
            var weightedY = 0.0
            var totalWeight = 0.0
            
            for j in 0..<windowSize {
                let idx = i + j - center
                if idx >= 0 && idx < points.count {
                    let weight = kernel[j]
                    weightedX += Double(points[idx].x) * weight
                    weightedY += Double(points[idx].y) * weight
                    totalWeight += weight
                }
            }
            
            if totalWeight > 0 {
                smoothed.append(CGPoint(
                    x: CGFloat(weightedX / totalWeight),
                    y: CGFloat(weightedY / totalWeight)
                ))
            } else {
                smoothed.append(points[i])
            }
        }
        
        return smoothed
    }
}

struct TurningPoint {
    let frameIndex: Int      // Index in trackedFrames array (NOT video frame number)
    let point: CGPoint
    let isMaximum: Bool
}

struct Ellipse {
    let startPoint: TurningPoint
    let endPoint: TurningPoint
    let angle: Double
    let frames: [TrackedFrame]
}

struct TrajectoryAnalysis {
    let ellipses: [Ellipse]
    let totalFrames: Int
    let averageAngle: Double
}
// MARK: - HammerTracker Class
class HammerTracker: ObservableObject {
    // Published properties for UI updates
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentTrajectory: Trajectory?
    @Published var analysisResult: TrajectoryAnalysis?
    
    // Core ML model
    private var detectionModel: VNCoreMLModel?
    
    // Tracking data
    private var trackedFrames: [TrackedFrame] = []
    private let confidenceThreshold: Float = 0.3
    private var lastDetectedFrameNumber: Int = -1  // Für Frame-Gap Regel
    private let maxFramesWithoutDetection = 10     // Nach 10 Frames ohne Detection beenden
    
    // Frame processing with optimized queues
    private let processingQueue = DispatchQueue(label: "com.hammertrack.processing", qos: .userInitiated, attributes: .concurrent)
    private let visionQueue = DispatchQueue(label: "com.hammertrack.vision", qos: .userInitiated)
    
    // Video properties
    private var videoOrientation: CGImagePropertyOrientation = .up
    private var videoNaturalSize: CGSize = .zero
    private var videoDisplaySize: CGSize = .zero
    private var videoTransform: CGAffineTransform = .identity
    
    init() {
        loadCoreMLModel()
    }
    
    // MARK: - Core ML Model Loading
    private func loadCoreMLModel() {
        // Try to find the model in the bundle
        guard let modelURL = Bundle.main.url(forResource: "best", withExtension: "mlpackage") else {
            // If not found as mlpackage, try mlmodelc
            if let compiledModelURL = Bundle.main.url(forResource: "best", withExtension: "mlmodelc") {
                do {
                    let config = MLModelConfiguration()
                    config.computeUnits = .cpuAndGPU
                    
                    let model = try MLModel(contentsOf: compiledModelURL, configuration: config)
                    detectionModel = try VNCoreMLModel(for: model)
                    print("CoreML compiled model loaded successfully from: \(compiledModelURL)")
                    return
                } catch {
                    print("Failed to load compiled CoreML model: \(error)")
                }
            }
            print("Failed to find model file. Searched for 'best.mlpackage' and 'best.mlmodelc'")
            return
        }
        
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndGPU
            
            let model = try MLModel(contentsOf: modelURL, configuration: config)
            detectionModel = try VNCoreMLModel(for: model)
            print("CoreML model loaded successfully from: \(modelURL)")
        } catch {
            print("Failed to load CoreML model: \(error)")
        }
    }    
    // MARK: - Video Processing
    func processVideo(url: URL, completion: @escaping (Result<Trajectory, Error>) -> Void) {
        resetTracking()
        
        let asset = AVAsset(url: url)
        let duration = asset.duration
        let durationTime = CMTimeGetSeconds(duration)
        
        guard let track = asset.tracks(withMediaType: .video).first else {
            completion(.failure(NSError(domain: "HammerTracker", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])))
            return
        }
        
        // Detect video orientation and size
        Task {
            do {
                let transform = try await track.load(.preferredTransform)
                let naturalSize = try await track.load(.naturalSize)
                
                self.videoTransform = transform
                self.videoNaturalSize = naturalSize
                self.videoOrientation = orientationFromTransform(transform, naturalSize: naturalSize)
                
                // Calculate the actual display size after transformation
                let transformedSize = naturalSize.applying(transform)
                self.videoDisplaySize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
                
                print("=== Video Properties ===")
                print("Natural size: \(naturalSize)")
                print("Transform: a=\(transform.a), b=\(transform.b), c=\(transform.c), d=\(transform.d)")
                print("Detected orientation: \(self.videoOrientation.rawValue)")
                print("Display size: \(self.videoDisplaySize)")
                print("Is portrait: \(self.videoDisplaySize.width < self.videoDisplaySize.height)")
            } catch {
                print("Error loading video properties: \(error)")
            }
        }
        
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            completion(.failure(error))
            return
        }
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()
        
        visionQueue.async { [weak self] in
            guard let self = self else { return }
            
            var frameNumber = 0
            var lastProgressUpdate: TimeInterval = 0
            let progressUpdateInterval: TimeInterval = 0.1 // Update every 100ms instead of every frame
            
            while reader.status == .reading {
                autoreleasepool {
                    if let sampleBuffer = output.copyNextSampleBuffer(),
                       let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        
                        let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                        
                        self.detectHammer(in: imageBuffer, frameNumber: frameNumber, timestamp: timestamp)
                        
                        frameNumber += 1
                        
                        // Throttled UI progress updates - only every 100ms instead of every frame
                        let currentTime = CACurrentMediaTime()
                        if currentTime - lastProgressUpdate >= progressUpdateInterval {
                            lastProgressUpdate = currentTime
                            let progressValue = timestamp / durationTime
                            Task { @MainActor in
                                self.progress = progressValue
                            }
                        }
                    }
                }
            }
            
            // Processing complete
            Task { @MainActor in
                self.isProcessing = false
                
                // Create trajectory with orientation information
                self.currentTrajectory = Trajectory(
                    frames: self.trackedFrames,
                    videoOrientation: self.videoOrientation,
                    videoSize: self.videoDisplaySize
                )
                
                if self.trackedFrames.isEmpty {
                    completion(.failure(NSError(domain: "HammerTracker", code: 2, userInfo: [NSLocalizedDescriptionKey: "No hammer detected in video"])))
                } else {
                    completion(.success(self.currentTrajectory!))
                }
            }
        }
    }    
    // MARK: - Live Camera Processing
    func processLiveFrame(_ imageBuffer: CVImageBuffer, frameNumber: Int) {
        let timestamp = Date().timeIntervalSince1970
        detectHammer(in: imageBuffer, frameNumber: frameNumber, timestamp: timestamp)
        
        // For live view, we store frames and can analyze them later
        Task { @MainActor in
            self.currentTrajectory = Trajectory(
                frames: self.trackedFrames,
                videoOrientation: self.videoOrientation,
                videoSize: self.videoDisplaySize
            )
        }
    }
    
    // MARK: - Hammer Detection with Proper Coordinate Transformation
    private func detectHammer(in imageBuffer: CVImageBuffer, frameNumber: Int, timestamp: TimeInterval) {
        guard let model = detectionModel else { 
            if frameNumber % 30 == 0 {
                print("No detection model available")
            }
            return 
        }
        
        // Check frame-gap rule (5 frames per specification)
        if lastDetectedFrameNumber >= 0 && frameNumber - lastDetectedFrameNumber > maxFramesWithoutDetection {
            print("\(maxFramesWithoutDetection) Frames ohne Detection - Analyse beendet bei Frame \(frameNumber)")
            // Signal that processing should stop (could set a flag here)
            return
        }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Detection error: \(error)")
                return
            }
            
            guard let results = request.results as? [VNRecognizedObjectObservation] else { 
                print("No results from detection")
                return 
            }
            
            // Debug output every second (disabled for performance)
            // if frameNumber % 30 == 0 && !results.isEmpty {
            //     print("Frame \(frameNumber): Found \(results.count) detections")
            // }
            
            // Find the best detection (highest confidence)
            if let bestDetection = results.max(by: { $0.confidence < $1.confidence }),
               bestDetection.confidence >= self.confidenceThreshold {
                let boundingBox = bestDetection.boundingBox
                
                // When using videoOrientation in the handler, we should get
                // correctly oriented coordinates - no transformation needed
                
                let trackedFrame = TrackedFrame(
                    frameNumber: frameNumber,
                    boundingBox: boundingBox,
                    confidence: bestDetection.confidence,
                    timestamp: timestamp
                )
                
                self.trackedFrames.append(trackedFrame)
                self.lastDetectedFrameNumber = frameNumber  // Update last detection
                
                if frameNumber % 30 == 0 {
                    print("\n=== Frame \(frameNumber) ===")
                    print("Video orientation: \(self.videoOrientation)")
                    print("Position: x=\(String(format: "%.3f", boundingBox.midX)), y=\(String(format: "%.3f", boundingBox.midY))")
                    print("Size: w=\(String(format: "%.3f", boundingBox.width)), h=\(String(format: "%.3f", boundingBox.height))")
                }
            }
        }
        
        // Use the video orientation directly for Vision
        // This should give us coordinates that match the displayed video
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: videoOrientation, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform detection: \(error)")
        }
    }    
    // MARK: - Professional Coordinate Transformation for iOS Videos
    private func transformBoundingBox(_ box: CGRect, orientation: CGImagePropertyOrientation) -> CGRect {
        // Vision coordinates are normalized (0-1) in the buffer's coordinate space
        // For iOS portrait videos, the buffer is in landscape orientation
        // but the video is displayed in portrait
        
        switch orientation {
        case .up, .upMirrored:
            // Standard landscape video - no transformation needed
            return box
            
        case .down, .downMirrored:
            // 180 degree rotation
            return CGRect(
                x: 1.0 - box.maxX,
                y: 1.0 - box.maxY,
                width: box.width,
                height: box.height
            )
            
        case .left, .leftMirrored:
            // 90 degrees CCW
            return CGRect(
                x: 1.0 - box.maxY,
                y: box.minX,
                width: box.height,
                height: box.width
            )
            
        case .right, .rightMirrored:
            // 90 degrees CW - This is typical for iOS portrait videos
            // The key insight: Vision gives us coordinates as if the video is landscape
            // But we display it as portrait, so we need to swap x and y
            // Transform: new_x = old_y, new_y = 1 - old_x
            return CGRect(
                x: box.minY,
                y: 1.0 - box.maxX,
                width: box.height,
                height: box.width
            )
        }
    }
    
    // MARK: - Improved Orientation Detection
    private func orientationFromTransform(_ transform: CGAffineTransform, naturalSize: CGSize) -> CGImagePropertyOrientation {
        var assetOrientation = CGImagePropertyOrientation.up
        
        // Check transform values for common orientations
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            // 90 degrees clockwise - typical for iOS portrait video
            assetOrientation = .right
            print("Detected: 90° CW rotation (typical iOS portrait)")
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            // 90 degrees counter-clockwise
            assetOrientation = .left
            print("Detected: 90° CCW rotation")
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            // No rotation
            assetOrientation = .up
            print("Detected: No rotation (landscape)")
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            // 180 degree rotation
            assetOrientation = .down
            print("Detected: 180° rotation")
        } else {
            // For other transforms, determine based on the result
            let transformedSize = naturalSize.applying(transform)
            if abs(transformedSize.width) < abs(transformedSize.height) {
                // Portrait orientation
                assetOrientation = .right
                print("Guessed portrait orientation based on aspect ratio")
            } else {
                // Landscape orientation
                assetOrientation = .up
                print("Guessed landscape orientation based on aspect ratio")
            }
        }
        
        return assetOrientation
    }    
    // MARK: - Trajectory Analysis
    func analyzeTrajectory() -> TrajectoryAnalysis? {
        guard trackedFrames.count > 20 else { return nil }
        
        let turningPoints = findTurningPoints()
        guard turningPoints.count >= 3 else {
            print("Nicht genug Umkehrpunkte gefunden: \(turningPoints.count). Mindestens 3 benötigt für eine Ellipse.")
            return nil
        }

        let ellipses = createEllipsesFromThreePoints(from: turningPoints)

        // Verwende alle erkannten Ellipsen
        let analyzedEllipses = ellipses

        guard !analyzedEllipses.isEmpty else {
            print("Keine Ellipsen für Analyse verfügbar.")
            return nil
        }
        
        let averageAngle = analyzedEllipses.reduce(0.0) { $0 + $1.angle } / Double(analyzedEllipses.count)
        
        let analysis = TrajectoryAnalysis(
            ellipses: analyzedEllipses,
            totalFrames: trackedFrames.count,
            averageAngle: averageAngle
        )
        
        DispatchQueue.main.async {
            self.analysisResult = analysis
        }
        
        print("=== Trajektorienanalyse abgeschlossen ===")
        print("Umkehrpunkte gesamt: \(turningPoints.count)")
        print("Ellipsen erstellt: \(ellipses.count)")
        print("Ellipsen analysiert: \(analyzedEllipses.count)")
        print("\n📊 Individuelle Ellipsen-Winkel:")
        for (index, ellipse) in analyzedEllipses.enumerated() {
            let direction = ellipse.angle > 0 ? "↗ rechts" : "↙ links"
            print("  Ellipse \(index + 1): \(String(format: "%.2f", ellipse.angle))° \(direction)")
        }
        print("\nDurchschnittlicher Winkel: \(String(format: "%.2f", averageAngle))°")

        // === NEU: Ausgabe ALLER detektierten Punkte für Python-Visualisierung ===
        print("\n📍 ALLE DETEKTIERTEN PUNKTE (\(trackedFrames.count) Frames):")
        print("Frame,X,Y")
        for frame in trackedFrames {
            let x = frame.boundingBox.midX
            let y = frame.boundingBox.midY
            print("\(frame.frameNumber),\(String(format: "%.6f", x)),\(String(format: "%.6f", y))")
        }

        return analysis
    }
    
    /// Erstellt Ellipsen basierend auf 3-Punkte-Trajektorien
    /// Der 3. Punkt einer Ellipse ist zugleich der 1. Punkt der nächsten Ellipse
    /// Ellipse 1: Punkte 1, 2, 3
    /// Ellipse 2: Punkte 3, 4, 5 (3 ist wiederholt)
    /// Ellipse 3: Punkte 5, 6, 7 (5 ist wiederholt)
    /// Ellipse 4: Punkte 7, 8, 9 (7 ist wiederholt)
    private func createEllipsesFromThreePoints(from turningPoints: [TurningPoint]) -> [Ellipse] {
        var ellipses: [Ellipse] = []

        // Wir brauchen mindestens 3 Punkte für die erste Ellipse
        guard turningPoints.count >= 3 else {
            print("Nicht genug Umkehrpunkte für Ellipsen (mindestens 3 benötigt)")
            return []
        }

        // Starte bei Index 0, dann bei jedem 2. Index (0, 2, 4, 6, ...)
        // Das gibt uns: (0,1,2), (2,3,4), (4,5,6), (6,7,8), ...
        var startIndex = 0
        var ellipseNumber = 1

        while startIndex + 2 < turningPoints.count {
            let firstPoint = turningPoints[startIndex]         // Punkt an Position startIndex
            let secondPoint = turningPoints[startIndex + 1]    // Punkt an Position startIndex+1
            let thirdPoint = turningPoints[startIndex + 2]     // Punkt an Position startIndex+2

            // Sicherheitsprüfung für Array-Zugriffe
            guard firstPoint.frameIndex >= 0 &&
                  thirdPoint.frameIndex < trackedFrames.count &&
                  firstPoint.frameIndex <= thirdPoint.frameIndex else {
                print("Warnung: Ungültige frameIndex Werte für Ellipse \(ellipseNumber)")
                startIndex += 2
                continue
            }

            // Berechne Winkel zwischen erstem und zweitem Punkt
            let angle = calculateEllipseAngleWithPythagoras(
                startPoint: firstPoint.point,
                endPoint: secondPoint.point
            )

            // Frames für diese Ellipse (vom ersten bis zum dritten Punkt)
            let ellipseFrames = Array(trackedFrames[firstPoint.frameIndex...thirdPoint.frameIndex])

            let ellipse = Ellipse(
                startPoint: firstPoint,
                endPoint: secondPoint, // Winkel basiert auf ersten beiden Punkten
                angle: angle,
                frames: ellipseFrames
            )

            ellipses.append(ellipse)

            print("Ellipse \(ellipseNumber): Umkehrpunkte[\(startIndex), \(startIndex+1), \(startIndex+2)] = P(\(String(format: "%.3f", firstPoint.point.x)), \(String(format: "%.3f", firstPoint.point.y))) → P(\(String(format: "%.3f", secondPoint.point.x)), \(String(format: "%.3f", secondPoint.point.y))) → P(\(String(format: "%.3f", thirdPoint.point.x)), \(String(format: "%.3f", thirdPoint.point.y))) | Winkel: \(String(format: "%.2f", angle))°")

            // Nächste Ellipse startet am 3. Punkt der aktuellen (Index +2)
            startIndex += 2
            ellipseNumber += 1
        }

        return ellipses
    }
    
    // MARK: - Turning Points Detection (FEDERUNGS-LOGIK / SPRING LOGIC)
    /// Findet Umkehrpunkte basierend auf reinen X-Achsen-Richtungsänderungen
    /// KEINE Schwellwerte, KEINE Heuristiken - nur Richtungswechsel!
    /// Wie eine Feder von der Seite betrachtet
    private func findTurningPoints() -> [TurningPoint] {
        guard trackedFrames.count > 2 else { return [] }

        var turningPoints: [TurningPoint] = []
        var currentDirection: Int? = nil

        // SCHRITT 1: Erster erkannter Punkt ist IMMER TP0
        let firstPoint = CGPoint(
            x: trackedFrames[0].boundingBox.midX,
            y: trackedFrames[0].boundingBox.midY
        )
        turningPoints.append(TurningPoint(
            frameIndex: 0,
            point: firstPoint,
            isMaximum: false
        ))
        print("🎯 Umkehrpunkt 0 (START): Frame \(trackedFrames[0].frameNumber) bei (\(String(format: "%.6f", firstPoint.x)), \(String(format: "%.6f", firstPoint.y)))")

        // SCHRITT 2: Initiale Richtung bestimmen (JEDE Bewegung zählt!)
        for i in 1..<trackedFrames.count {
            let dx = trackedFrames[i].boundingBox.midX - trackedFrames[i-1].boundingBox.midX

            if dx != 0 {  // Keine Schwellwerte! Jede Bewegung zählt
                currentDirection = dx > 0 ? 1 : -1
                print("🧭 Initiale Richtung: \(currentDirection! > 0 ? "RECHTS →" : "LINKS ←") bei Frame \(trackedFrames[i].frameNumber)")
                break
            }
        }

        guard currentDirection != nil else {
            print("⚠️ Keine X-Bewegung erkannt - keine Ellipsen möglich")
            return turningPoints
        }

        // SCHRITT 3: Alle Richtungsänderungen finden
        for i in 1..<trackedFrames.count {
            let dx = trackedFrames[i].boundingBox.midX - trackedFrames[i-1].boundingBox.midX

            // Nur bei tatsächlicher Bewegung prüfen
            if dx != 0 {
                let newDirection = dx > 0 ? 1 : -1

                // Richtungswechsel erkannt?
                if newDirection != currentDirection {
                    let point = CGPoint(
                        x: trackedFrames[i-1].boundingBox.midX,
                        y: trackedFrames[i-1].boundingBox.midY
                    )

                    let isMaximum = currentDirection! > 0
                    turningPoints.append(TurningPoint(
                        frameIndex: i-1,
                        point: point,
                        isMaximum: isMaximum
                    ))

                    print("🔄 TP\(turningPoints.count-1): Frame \(trackedFrames[i-1].frameNumber)")
                    print("   Position: (\(String(format: "%.6f", point.x)), \(String(format: "%.6f", point.y)))")
                    print("   Wechsel: \(currentDirection! > 0 ? "RECHTS→LINKS" : "LINKS→RECHTS")")
                    print("   Typ: \(isMaximum ? "MAXIMUM" : "MINIMUM")")

                    currentDirection = newDirection
                }
            }
        }

        print("\n=== Umkehrpunkt-Erkennung abgeschlossen ===")
        print("✅ \(turningPoints.count) Umkehrpunkte gefunden")
        for (index, tp) in turningPoints.enumerated() {
            print("  TP\(index): Frame \(trackedFrames[tp.frameIndex].frameNumber), " +
                  "(\(String(format: "%.3f", tp.point.x)), \(String(format: "%.3f", tp.point.y))), " +
                  "\(tp.isMaximum ? "MAX" : "MIN")")
        }

        return turningPoints
    }
    
    
    /// Berechnet den Ellipsenwinkel mit atan2 (robuster)
    /// - Parameters:
    ///   - startPoint: Erster Umkehrpunkt der Trajektorie
    ///   - endPoint: Zweiter Umkehrpunkt der Trajektorie
    /// - Returns: Winkel in Grad (positiv = fällt nach links, negativ = fällt nach rechts)
    ///           Entsprechend der Spezifikation: "Wenn der erste punkt höher liegt als der zweite fällt die elypse nach links"
    private func calculateEllipseAngleWithPythagoras(startPoint: CGPoint, endPoint: CGPoint) -> Double {
        // Berechne die Differenzen (mit Vorzeichen)
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y

        // Prüfe auf minimale Bewegung
        guard abs(dx) > 0.001 || abs(dy) > 0.001 else {
            return 0.0 // Keine Bewegung
        }

        // Verwende atan2 für robusten signierten Winkel
        // atan2(dy, dx) gibt den Winkel von der x-Achse aus
        let angleRadians = atan2(abs(dy), abs(dx))
        let angleDegrees = angleRadians * 180.0 / .pi

        // Richtung bestimmen basierend auf der Spezifikation:
        // In Vision/UIKit Koordinaten: Y=0 ist OBEN, Y=1 ist UNTEN
        // Wenn startPoint.y < endPoint.y: Erster Punkt ist HÖHER (kleinere Y) → fällt nach LINKS → positiver Winkel
        // Wenn startPoint.y > endPoint.y: Erster Punkt ist NIEDRIGER (größere Y) → fällt nach RECHTS → negativer Winkel

        if startPoint.y < endPoint.y {
            // Erster Punkt höher (kleinere Y-Koordinate) → Trajektorie fällt nach links → positiver Winkel
            return angleDegrees
        } else {
            // Erster Punkt niedriger (größere Y-Koordinate) → Trajektorie fällt nach rechts → negativer Winkel
            return -angleDegrees
        }
    }
    
    // MARK: - Helper Methods
    func resetTracking() {
        trackedFrames.removeAll()
        currentTrajectory = nil
        analysisResult = nil
        progress = 0.0
        isProcessing = true
        lastDetectedFrameNumber = -1  // Reset last detection tracker
    }
    
    func getTrajectoryForDisplay(videoSize: CGSize, displaySize: CGSize) -> [CGPoint] {
        guard let trajectory = currentTrajectory else { return [] }
        
        return trajectory.smoothedPoints.map { point in
            CGPoint(
                x: point.x * displaySize.width,
                y: point.y * displaySize.height
            )
        }
    }
    
    func getTrajectoryForLive() -> Trajectory {
        return Trajectory(
            frames: trackedFrames,
            videoOrientation: videoOrientation,
            videoSize: videoDisplaySize
        )
    }
    
    func performLiveEllipseAnalysis() {
        guard trackedFrames.count > 20 else { return }
        
        let result = analyzeTrajectory()
        if let analysisResult = result {
            logAnalysisResults(analysisResult)
        }
    }
    
    private func logAnalysisResults(_ analysis: TrajectoryAnalysis) {
        print("=== Trajectory Analysis Results ===")
        print("Total frames analyzed: \(analysis.totalFrames)")
        print("Number of ellipses: \(analysis.ellipses.count)")
        print("Average angle: \(String(format: "%.2f", analysis.averageAngle))°")
        
        for (index, ellipse) in analysis.ellipses.enumerated() {
            print("Ellipse \(index + 1): Angle = \(String(format: "%.2f", ellipse.angle))°")
        }
    }
}