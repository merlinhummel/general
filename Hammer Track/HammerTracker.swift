import Foundation
import CoreML
import Vision
import AVFoundation
import UIKit
import CoreGraphics

// MARK: - Data Models
struct TrackedFrame {
    let frameNumber: Int
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
    let frameIndex: Int
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
            if let bestDetection = results.first(where: { $0.confidence >= self.confidenceThreshold }) {
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
            print("Nicht genug Umkehrpunkte gefunden: \(turningPoints.count). Mindestens 3 benötigt.")
            return nil 
        }
        
        let ellipses = createEllipsesFromThreePoints(from: turningPoints)
        
        // Skip the first 2 ellipses as requested
        let analyzedEllipses = Array(ellipses.dropFirst(2))
        
        guard !analyzedEllipses.isEmpty else { 
            print("Keine Ellipsen nach dem Überspringen der ersten 2 verfügbar.")
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
        print("Ellipsen analysiert (nach Überspringen): \(analyzedEllipses.count)")
        print("Durchschnittlicher Winkel: \(String(format: "%.2f", averageAngle))°")
        
        return analysis
    }
    
    /// Erstellt Ellipsen basierend auf 3-Punkte-Trajektorien
    /// Der 3. Punkt einer Trajektorie ist der 1. Punkt der nächsten
    private func createEllipsesFromThreePoints(from turningPoints: [TurningPoint]) -> [Ellipse] {
        var ellipses: [Ellipse] = []
        
        // Gehe durch alle möglichen 3-Punkte-Kombinationen
        // Punkt i, i+1, i+2 bilden eine Ellipse
        // Der Winkel wird zwischen Punkt i und i+1 berechnet
        for i in 0..<(turningPoints.count - 2) {
            let firstPoint = turningPoints[i]      // Punkt 1 der Trajektorie
            let secondPoint = turningPoints[i + 1] // Punkt 2 der Trajektorie  
            let thirdPoint = turningPoints[i + 2]  // Punkt 3 der Trajektorie (wird zu Punkt 1 der nächsten)
            
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
            
            print("3-Punkt-Ellipse \(i+1): P1(\(String(format: "%.3f", firstPoint.point.x)), \(String(format: "%.3f", firstPoint.point.y))) -> P2(\(String(format: "%.3f", secondPoint.point.x)), \(String(format: "%.3f", secondPoint.point.y))) -> P3(\(String(format: "%.3f", thirdPoint.point.x)), \(String(format: "%.3f", thirdPoint.point.y))) | Winkel: \(String(format: "%.2f", angle))°")
        }
        
        return ellipses
    }
    
    // MARK: - Turning Points Detection (Optimiert für 3-Punkte-Ellipsen)
    private func findTurningPoints() -> [TurningPoint] {
        guard trackedFrames.count > 15 else { return [] } // Erhöht von 7 auf 15
        
        var turningPoints: [TurningPoint] = []
        var currentDirection: Int? = nil
        
        // Verbesserte Parameter für stabilere Erkennung
        let minConsistentFrames = 10  // Mindestens 10 konsistente Frames
        let minMovementThreshold = 0.015  // Erhöht von 0.01 auf 0.015
        
        // Find the first valid starting point
        var startIndex = 0
        for i in 0..<(trackedFrames.count - minConsistentFrames) {
            let startX = trackedFrames[i].boundingBox.midX
            var consistent = true
            var direction = 0
            
            // Check if next frames go consistently in one direction
            for j in 1...minConsistentFrames {
                if i + j >= trackedFrames.count { break }
                let currentX = trackedFrames[i + j].boundingBox.midX
                let diff = currentX - startX
                
                if abs(diff) < minMovementThreshold {
                    consistent = false
                    break
                }
                
                let frameDirection = diff > 0 ? 1 : -1
                if direction == 0 {
                    direction = frameDirection
                } else if direction != frameDirection {
                    consistent = false
                    break
                }
            }
            
            if consistent && direction != 0 {
                startIndex = i
                currentDirection = direction
                let point = CGPoint(
                    x: trackedFrames[i].boundingBox.midX,
                    y: trackedFrames[i].boundingBox.midY
                )
                turningPoints.append(TurningPoint(
                    frameIndex: i,
                    point: point,
                    isMaximum: direction < 0
                ))
                print("Startpunkt gefunden bei Frame \(i): Richtung \(direction > 0 ? "rechts" : "links")")
                break
            }
        }
        
        // Find subsequent turning points with improved logic
        var framesSinceLastTurn = 0
        let minFramesBetweenTurns = 15  // Mindestabstand zwischen Umkehrpunkten
        
        for i in (startIndex + 1)..<trackedFrames.count {
            // Check for time jumps (skip if too much time passed)
            if i > 0 && trackedFrames[i].timestamp - trackedFrames[i-1].timestamp > 15.0/30.0 {
                print("Zeitsprung erkannt bei Frame \(i), Analyse beendet")
                break
            }
            
            framesSinceLastTurn += 1
            
            if i == 0 { continue }
            
            let currentX = trackedFrames[i].boundingBox.midX
            let previousX = trackedFrames[i-1].boundingBox.midX
            let diff = currentX - previousX
            
            if abs(diff) > minMovementThreshold && framesSinceLastTurn >= minFramesBetweenTurns {
                let frameDirection = diff > 0 ? 1 : -1
                
                if let dir = currentDirection, frameDirection != dir {
                    // Direction changed - we found a turning point
                    let point = CGPoint(
                        x: trackedFrames[i-1].boundingBox.midX,
                        y: trackedFrames[i-1].boundingBox.midY
                    )
                    turningPoints.append(TurningPoint(
                        frameIndex: i-1,
                        point: point,
                        isMaximum: dir > 0
                    ))
                    print("Umkehrpunkt \(turningPoints.count) bei Frame \(i-1): \(dir > 0 ? "Maximum" : "Minimum") -> \(frameDirection > 0 ? "rechts" : "links")")
                    currentDirection = frameDirection
                    framesSinceLastTurn = 0
                }
            }
        }
        
        print("=== Umkehrpunkt-Erkennung abgeschlossen ===")
        print("Gefunden: \(turningPoints.count) Umkehrpunkte")
        for (index, point) in turningPoints.enumerated() {
            print("  Punkt \(index + 1): Frame \(point.frameIndex), Position (\(String(format: "%.3f", point.point.x)), \(String(format: "%.3f", point.point.y))), \(point.isMaximum ? "Maximum" : "Minimum")")
        }
        
        return turningPoints
    }
    
    // MARK: - Ellipse Creation (Legacy - 2-Punkt-Ellipsen)
    private func createEllipses(from turningPoints: [TurningPoint]) -> [Ellipse] {
        var ellipses: [Ellipse] = []
        
        for i in 0..<(turningPoints.count - 1) {
            let startPoint = turningPoints[i]
            let endPoint = turningPoints[i + 1]
            
            // Berechne Winkel mit Pythagoras (Hypothenusenwinkel)
            let angle = calculateEllipseAngleWithPythagoras(
                startPoint: startPoint.point, 
                endPoint: endPoint.point
            )
            
            // Get frames for this ellipse
            let ellipseFrames = Array(trackedFrames[startPoint.frameIndex...endPoint.frameIndex])
            
            let ellipse = Ellipse(
                startPoint: startPoint,
                endPoint: endPoint,
                angle: angle,
                frames: ellipseFrames
            )
            
            ellipses.append(ellipse)
            
            // Debug output für jede Ellipse (disabled for performance)
            // print("Ellipse \(i+1): Start(\(String(format: "%.3f", startPoint.point.x)), \(String(format: "%.3f", startPoint.point.y))) -> End(\(String(format: "%.3f", endPoint.point.x)), \(String(format: "%.3f", endPoint.point.y))) = \(String(format: "%.2f", angle))° \(angle > 0 ? "rechts" : "links")")
        }
        
        return ellipses
    }
    
    /// Berechnet den Ellipsenwinkel mit Pythagoras
    /// - Parameters:
    ///   - startPoint: Erster Umkehrpunkt der Trajektorie
    ///   - endPoint: Zweiter Umkehrpunkt der Trajektorie
    /// - Returns: Winkel in Grad (positiv = fällt nach rechts, negativ = fällt nach links)
    private func calculateEllipseAngleWithPythagoras(startPoint: CGPoint, endPoint: CGPoint) -> Double {
        // Abstände berechnen
        let horizontalDistance = abs(endPoint.x - startPoint.x)  // Ankathete
        let verticalDistance = abs(endPoint.y - startPoint.y)    // Gegenkathete
        
        // Prüfe auf gültigen horizontalen Abstand
        guard horizontalDistance > 0.001 else {
            return 0.0 // Vertikale Linie, kein Winkel
        }
        
        // Hypothenuse mit Pythagoras: c² = a² + b²
        let hypotenuse = sqrt(horizontalDistance * horizontalDistance + verticalDistance * verticalDistance)
        
        // Winkel berechnen: sin(angle) = Gegenkathete / Hypothenuse
        let angleRadians = asin(verticalDistance / hypotenuse)
        let angleDegrees = angleRadians * 180.0 / .pi
        
        // Richtung bestimmen: Welcher Punkt ist höher?
        // In normalisierten Koordinaten: Y=0 ist unten, Y=1 ist oben
        let isStartPointHigher = startPoint.y > endPoint.y
        
        if isStartPointHigher {
            // Erster Punkt höher → Trajektorie fällt nach rechts → positiver Winkel
            return angleDegrees
        } else {
            // Zweiter Punkt höher → Trajektorie fällt nach links → negativer Winkel
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