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
    
    var points: [CGPoint] {
        return frames.map { frame in
            CGPoint(x: frame.boundingBox.midX, y: frame.boundingBox.midY)
        }
    }
    
    // Smoothed points using simple moving average
    var smoothedPoints: [CGPoint] {
        guard points.count > 3 else { return points }
        
        var smoothed: [CGPoint] = []
        let windowSize = 5
        
        for i in 0..<points.count {
            let startIdx = max(0, i - windowSize / 2)
            let endIdx = min(points.count - 1, i + windowSize / 2)
            
            var sumX: CGFloat = 0
            var sumY: CGFloat = 0
            var count = 0
            
            for j in startIdx...endIdx {
                sumX += points[j].x
                sumY += points[j].y
                count += 1
            }
            
            smoothed.append(CGPoint(x: sumX / CGFloat(count), y: sumY / CGFloat(count)))
        }
        
        return smoothed
    }
}

struct TurningPoint {
    let frameIndex: Int
    let point: CGPoint
    let isMaximum: Bool // true if it's a maximum (rightmost), false if minimum (leftmost)
}

struct Ellipse {
    let startPoint: TurningPoint
    let endPoint: TurningPoint
    let angle: Double // in degrees, positive = tilted right, negative = tilted left
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
    private let confidenceThreshold: Float = 0.3 // Lowered for testing
    
    // Frame processing
    private let processingQueue = DispatchQueue(label: "com.hammertrack.processing", qos: .userInitiated)
    
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
                    let model = try MLModel(contentsOf: compiledModelURL)
                    detectionModel = try VNCoreMLModel(for: model)
                    print("CoreML compiled model loaded successfully from: \(compiledModelURL)")
                    return
                } catch {
                    print("Failed to load compiled CoreML model: \(error)")
                }
            }
            print("Failed to find model file. Searched for 'best.mlpackage' and 'best.mlmodelc'")
            
            // Debug: Print bundle contents
            if let resourcePath = Bundle.main.resourcePath {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    print("Bundle contents: \(contents.filter { $0.contains("best") || $0.contains(".ml") })")
                } catch {
                    print("Failed to list bundle contents: \(error)")
                }
            }
            return
        }
        
        do {
            let model = try MLModel(contentsOf: modelURL)
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
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            var frameNumber = 0
            let frameRate = track.nominalFrameRate
            
            while reader.status == .reading {
                autoreleasepool {
                    if let sampleBuffer = output.copyNextSampleBuffer(),
                       let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        
                        let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                        
                        self.detectHammer(in: imageBuffer, frameNumber: frameNumber, timestamp: timestamp)
                        
                        frameNumber += 1
                        
                        // Update progress
                        DispatchQueue.main.async {
                            self.progress = timestamp / durationTime
                        }
                    }
                }
            }
            
            // Processing complete
            DispatchQueue.main.async {
                self.isProcessing = false
                self.currentTrajectory = Trajectory(frames: self.trackedFrames)
                
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
        DispatchQueue.main.async {
            self.currentTrajectory = Trajectory(frames: self.trackedFrames)
        }
    }
    
    // MARK: - Hammer Detection
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
            
            // Debug: Print all detections
            if frameNumber % 30 == 0 { // Every second at 30fps
                print("Frame \(frameNumber): Found \(results.count) detections")
                for (index, detection) in results.enumerated() {
                    print("  Detection \(index): Label=\(detection.labels.first?.identifier ?? "unknown"), Confidence=\(detection.confidence), Box=\(detection.boundingBox)")
                }
            }
            
            // Find the best detection (highest confidence)
            // Lower threshold to 0.3 for testing
            if let bestDetection = results.first(where: { $0.confidence >= 0.3 }) {
                var boundingBox = bestDetection.boundingBox
                
                // Fix for 90-degree rotation issue common with CoreML models
                // Rotate the bounding box coordinates by 90 degrees clockwise
                let rotatedBox = CGRect(
                    x: 1.0 - boundingBox.maxY,
                    y: boundingBox.minX,
                    width: boundingBox.height,
                    height: boundingBox.width
                )
                
                let trackedFrame = TrackedFrame(
                    frameNumber: frameNumber,
                    boundingBox: rotatedBox,
                    confidence: bestDetection.confidence,
                    timestamp: timestamp
                )
                
                self.trackedFrames.append(trackedFrame)
                
                if frameNumber % 30 == 0 {
                    print("Tracked frame \(frameNumber) with confidence \(bestDetection.confidence)")
                    print("Original box: \(boundingBox), Rotated box: \(rotatedBox)")
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform detection: \(error)")
        }
    }
    
    // MARK: - Trajectory Analysis
    func analyzeTrajectory() -> TrajectoryAnalysis? {
        guard trackedFrames.count > 20 else { return nil }
        
        let turningPoints = findTurningPoints()
        guard turningPoints.count >= 2 else { return nil }
        
        let ellipses = createEllipses(from: turningPoints)
        
        // Skip the first 2 ellipses as requested
        let analyzedEllipses = Array(ellipses.dropFirst(2))
        
        guard !analyzedEllipses.isEmpty else { return nil }
        
        let averageAngle = analyzedEllipses.reduce(0.0) { $0 + $1.angle } / Double(analyzedEllipses.count)
        
        let analysis = TrajectoryAnalysis(
            ellipses: analyzedEllipses,
            totalFrames: trackedFrames.count,
            averageAngle: averageAngle
        )
        
        DispatchQueue.main.async {
            self.analysisResult = analysis
        }
        
        return analysis
    }
    
    // MARK: - Turning Points Detection
    private func findTurningPoints() -> [TurningPoint] {
        guard trackedFrames.count > 7 else { return [] }
        
        var turningPoints: [TurningPoint] = []
        var currentDirection: Int? = nil // 1 for positive (right), -1 for negative (left)
        
        // Find the first valid starting point
        var startIndex = 0
        for i in 0..<(trackedFrames.count - 7) {
            let startX = trackedFrames[i].boundingBox.midX
            var consistent = true
            var direction = 0
            
            // Check if next 7 frames go consistently in one direction
            for j in 1...7 {
                if i + j >= trackedFrames.count { break }
                let currentX = trackedFrames[i + j].boundingBox.midX
                let diff = currentX - startX
                
                if abs(diff) < 0.01 { // Increased threshold for more stable detection
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
                    isMaximum: direction < 0 // If starting to go left, this is a maximum
                ))
                break
            }
        }
        
        // Find subsequent turning points
        var noDetectionCount = 0
        for i in (startIndex + 1)..<trackedFrames.count {
            // Check if we've had 15 frames without detection (end condition)
            if i > 0 && trackedFrames[i].timestamp - trackedFrames[i-1].timestamp > 15.0/30.0 {
                break
            }
            
            if i == 0 { continue }
            
            let currentX = trackedFrames[i].boundingBox.midX
            let previousX = trackedFrames[i-1].boundingBox.midX
            let diff = currentX - previousX
            
            if abs(diff) > 0.001 { // Significant movement
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
                        isMaximum: dir > 0 // Was going right, so this is a maximum
                    ))
                    currentDirection = frameDirection
                }
            }
        }
        
        return turningPoints
    }
    
    // MARK: - Ellipse Creation
    private func createEllipses(from turningPoints: [TurningPoint]) -> [Ellipse] {
        var ellipses: [Ellipse] = []
        
        for i in 0..<(turningPoints.count - 1) {
            let startPoint = turningPoints[i]
            let endPoint = turningPoints[i + 1]
            
            // Calculate angle
            let heightDiff = endPoint.point.y - startPoint.point.y
            let horizontalDist = abs(endPoint.point.x - startPoint.point.x)
            
            var angle: Double = 0.0
            if horizontalDist > 0.001 {
                angle = atan(heightDiff / horizontalDist) * 180.0 / .pi
                
                // Adjust sign based on tilt direction
                // If start point is higher (smaller y), ellipse tilts left (negative angle)
                // If start point is lower (larger y), ellipse tilts right (positive angle)
                if startPoint.point.y < endPoint.point.y {
                    angle = -abs(angle) // Tilts left
                } else {
                    angle = abs(angle) // Tilts right
                }
            }
            
            // Get frames for this ellipse
            let ellipseFrames = Array(trackedFrames[startPoint.frameIndex...endPoint.frameIndex])
            
            let ellipse = Ellipse(
                startPoint: startPoint,
                endPoint: endPoint,
                angle: angle,
                frames: ellipseFrames
            )
            
            ellipses.append(ellipse)
        }
        
        return ellipses
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
            // Convert from normalized coordinates (0-1) to display coordinates
            CGPoint(
                x: point.x * displaySize.width,
                y: (1.0 - point.y) * displaySize.height // Flip Y coordinate
            )
        }
    }
    
    func getTrajectoryForLive() -> Trajectory {
        return Trajectory(frames: trackedFrames)
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
