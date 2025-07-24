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
    
    // Frame processing
    private let processingQueue = DispatchQueue(label: "com.hammertrack.processing", qos: .userInitiated)
    
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
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            var frameNumber = 0
            
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
        DispatchQueue.main.async {
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
            
            // Debug output every second
            if frameNumber % 30 == 0 && !results.isEmpty {
                print("Frame \(frameNumber): Found \(results.count) detections")
            }
            
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
        var currentDirection: Int? = nil
        
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
                
                if abs(diff) < 0.01 {
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
                break
            }
        }
        
        // Find subsequent turning points
        for i in (startIndex + 1)..<trackedFrames.count {
            if i > 0 && trackedFrames[i].timestamp - trackedFrames[i-1].timestamp > 15.0/30.0 {
                break
            }
            
            if i == 0 { continue }
            
            let currentX = trackedFrames[i].boundingBox.midX
            let previousX = trackedFrames[i-1].boundingBox.midX
            let diff = currentX - previousX            
            if abs(diff) > 0.001 {
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
                // In UIKit coordinates: y=0 is top, y increases downward
                // If startPoint.y < endPoint.y: first point is higher (closer to top) → falls to the right
                // If startPoint.y > endPoint.y: second point is higher → falls to the left
                if startPoint.point.y < endPoint.point.y {
                    angle = abs(angle) // Tilts right (positive angle)
                } else {
                    angle = -abs(angle) // Tilts left (negative angle)
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