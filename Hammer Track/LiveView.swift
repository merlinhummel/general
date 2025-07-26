import SwiftUI
import AVFoundation
import Vision
import Speech

struct LiveView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isAnalysisMode = false
    @State private var showAnalysisResults = false
    @State private var analysisResultText = ""
    @StateObject private var hammerTracker = HammerTracker()
    @State private var showFocusIndicator = false
    @State private var focusLocation = CGPoint.zero
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: {
                    // Stop camera and go back
                    cameraManager.stopSession()
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Zurück")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("Live View")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Placeholder for balance
                Color.clear
                    .frame(width: 60, height: 20)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            
            // Main content area with camera
            ZStack {
                // Camera Preview with tap to focus
                CameraPreview(session: cameraManager.session, onTap: { location in
                    focusLocation = location
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showFocusIndicator = true
                    }
                    cameraManager.setFocus(at: location)
                    
                    // Hide focus indicator after a moment
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showFocusIndicator = false
                        }
                    }
                })
                    .ignoresSafeArea(edges: .bottom)
                
                // Focus indicator
                if showFocusIndicator {
                    FocusIndicatorView()
                        .position(focusLocation)
                        .allowsHitTesting(false)
                }
            
            // Overlay Controls
            VStack {
                Spacer()
                
                if isAnalysisMode {
                    // Analysis status at top
                    VStack(alignment: .center, spacing: 4) {
                        HStack {
                            Text(cameraManager.isDetectingPose ? "Arm erkannt - Bereit" : "Arm heben zum Start")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                            if cameraManager.isActivelyTracking {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.red, lineWidth: 2)
                                            .scaleEffect(1.5)
                                            .opacity(0.5)
                                            .animation(.easeInOut(duration: 1).repeatForever(), value: cameraManager.isActivelyTracking)
                                    )
                            }
                        }
                        
                        if cameraManager.framesWithoutHammer > 0 && cameraManager.isActivelyTracking {
                            Text("Frames ohne Hammer: \(cameraManager.framesWithoutHammer)/7")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(cameraManager.isActivelyTracking ? Color.red : Color.orange)
                    .cornerRadius(15)
                    .padding(.top, 20)
                }
                
                Spacer()
                
                // Analysis Results Overlay
                if showAnalysisResults && !analysisResultText.isEmpty {
                    VStack {
                        Text("Analyse Ergebnisse:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(analysisResultText)
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    .transition(.opacity)
                }
                
                Spacer()
                
                // Bottom Controls
                VStack(spacing: 20) {
                    if !isAnalysisMode {
                        Button(action: startAnalysis) {
                            HStack {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.title2)
                                Text("Live Analyse starten")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.blue)
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                    } else {
                        VStack(spacing: 15) {
                            // Status indicator
                            Text(cameraManager.poseDetectionStatus)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(20)
                            
                            // Stop Analysis
                            Button(action: stopAnalysis) {
                                Text("Analyse beenden")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.gray)
                                    .cornerRadius(20)
                            }
                        }
                        
                        // Frame count indicator
                        if let trajectory = hammerTracker.currentTrajectory, trajectory.frames.count > 0 {
                            Text("\(trajectory.frames.count) Hammer-Frames erkannt")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(10)
                        }
                    }
                    
                    // Camera Settings
                    VStack(spacing: 15) {
                        // Zoom Controls
                        HStack(spacing: 10) {
                            ForEach(cameraManager.availableZoomFactors, id: \.self) { factor in
                                Button(action: {
                                    cameraManager.setZoomFactor(factor)
                                }) {
                                    Text("\(factor, specifier: "%.1f")x")
                                        .font(.system(size: 14, weight: cameraManager.currentZoomFactor == factor ? .bold : .regular))
                                        .foregroundColor(cameraManager.currentZoomFactor == factor ? .black : .white)
                                        .frame(width: 45, height: 35)
                                        .background(cameraManager.currentZoomFactor == factor ? Color.white : Color.black.opacity(0.5))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        HStack(spacing: 20) {
                            // Flash Toggle
                            Button(action: {
                                cameraManager.toggleFlash()
                            }) {
                                Image(systemName: cameraManager.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            
                            // Camera Switch
                            Button(action: {
                                cameraManager.switchCamera()
                            }) {
                                Image(systemName: "camera.rotate")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            cameraManager.checkPermissions()
            cameraManager.hammerTracker = hammerTracker
            cameraManager.onAnalysisComplete = { results in
                self.analysisResultText = results
                withAnimation {
                    self.showAnalysisResults = true
                }
                
                // Hide results after 10 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    withAnimation {
                        self.showAnalysisResults = false
                    }
                }
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .alert("Kamera Zugriff", isPresented: $cameraManager.showAlert) {
            Button("OK") {
                // Open settings
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
        } message: {
            Text("Diese App benötigt Zugriff auf die Kamera für die Live-Analyse.")
        }
    }
    
    private func startAnalysis() {
        withAnimation {
            isAnalysisMode = true
            cameraManager.startLiveAnalysis()
        }
    }
    
    private func stopAnalysis() {
        withAnimation {
            isAnalysisMode = false
            showAnalysisResults = false
            cameraManager.stopLiveAnalysis()
        }
    }
}

// Camera Manager with Pose Detection
class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var showAlert = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var isDetectingPose = false
    @Published var isActivelyTracking = false
    @Published var poseDetectionStatus = "Warte auf Arm-Bewegung..."
    @Published var framesWithoutHammer = 0
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var availableZoomFactors: [CGFloat] = [1.0]
    
    private var output = AVCaptureMovieFileOutput()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var currentCamera: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    weak var hammerTracker: HammerTracker?
    private var frameCount = 0
    private var isAnalyzing = false
    
    // Pose Detection
    private var poseRequest: VNDetectHumanBodyPoseRequest?
    private var lastArmPosition: VNRecognizedPoint?
    private var armRaisedStartTime: Date?
    private let armRaisedThreshold: TimeInterval = 0.2 // Arm muss 0.2 Sekunden gehoben bleiben
    
    // Analysis tracking
    private var consecutiveFramesWithoutHammer = 0
    private let maxFramesWithoutHammer = 7
    private var analysisStartFrame = 0
    
    // Audio
    private let audioPlayer = AVAudioPlayer()
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // Callback for analysis results
    var onAnalysisComplete: ((String) -> Void)?
    
    override init() {
        super.init()
        setupSession()
        setupPoseDetection()
    }
    
    private func setupPoseDetection() {
        poseRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Pose detection error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNHumanBodyPoseObservation],
                  let observation = observations.first else { return }
            
            self.processPoseObservation(observation)
        }
    }
    
    private func processPoseObservation(_ observation: VNHumanBodyPoseObservation) {
        do {
            // Get right wrist position (kann auch left wrist nehmen)
            let rightWrist = try observation.recognizedPoint(.rightWrist)
            let rightElbow = try observation.recognizedPoint(.rightElbow)
            let rightShoulder = try observation.recognizedPoint(.rightShoulder)
            
            // Check if arm is raised (wrist higher than elbow and elbow higher than shoulder)
            let isArmRaised = rightWrist.y > rightElbow.y && rightElbow.y > rightShoulder.y && rightWrist.confidence > 0.3
            
            DispatchQueue.main.async {
                if isArmRaised && !self.isActivelyTracking && self.isAnalyzing {
                    // Arm is raised
                    if self.armRaisedStartTime == nil {
                        self.armRaisedStartTime = Date()
                        self.isDetectingPose = true
                        self.poseDetectionStatus = "Arm erkannt - halte Position..."
                    } else if let startTime = self.armRaisedStartTime,
                              Date().timeIntervalSince(startTime) >= self.armRaisedThreshold {
                        // Arm has been raised long enough - start tracking
                        self.startTrackingHammer()
                    }
                } else if !isArmRaised && self.armRaisedStartTime != nil && !self.isActivelyTracking {
                    // Arm lowered before threshold
                    self.armRaisedStartTime = nil
                    self.isDetectingPose = false
                    self.poseDetectionStatus = "Arm heben zum Start"
                }
            }
            
            self.lastArmPosition = rightWrist
            
        } catch {
            // Pose points not available
        }
    }
    
    private func startTrackingHammer() {
        self.isActivelyTracking = true
        self.isDetectingPose = false
        self.poseDetectionStatus = "Hammer-Tracking läuft..."
        self.consecutiveFramesWithoutHammer = 0
        self.analysisStartFrame = self.frameCount
        
        // Reset hammer tracker
        self.hammerTracker?.resetTracking()
        
        // Play start sound
        self.playStartSound()
        
        print("Started hammer tracking at frame \(self.frameCount)")
    }
    
    private func playStartSound() {
        // System sound for start
        AudioServicesPlaySystemSound(1113) // Begin recording sound
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.startSession()
                    }
                }
            }
        case .denied, .restricted:
            showAlert = true
        @unknown default:
            break
        }
    }
    
    private func setupSession() {
        session.beginConfiguration()
        
        // Add video input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return
        }
        
        currentCamera = camera
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            
            if session.canAddInput(input) {
                session.addInput(input)
                videoDeviceInput = input
            }
            
            // Add movie output for recording
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            // Add video data output for live processing
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            
            if session.canAddOutput(videoDataOutput) {
                session.addOutput(videoDataOutput)
            }
            
        } catch {
            print("Error setting up camera: \(error)")
        }
        
        session.commitConfiguration()
        
        // Setup available zoom factors
        updateAvailableZoomFactors()
    }
    
    // MARK: - Focus and Zoom Methods
    
    func setFocus(at point: CGPoint) {
        guard let device = currentCamera else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting focus: \(error)")
        }
    }
    
    func setZoomFactor(_ factor: CGFloat) {
        guard let device = currentCamera else { return }
        
        // For 0.5x, try to switch to ultra-wide camera
        if factor == 0.5 {
            if let ultraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
                switchToCamera(ultraWide)
                currentZoomFactor = factor
                return
            }
        }
        
        // For standard zoom levels, use the wide camera with zoom
        if let wideCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            if device != wideCamera {
                switchToCamera(wideCamera)
            }
        }
        
        do {
            try device.lockForConfiguration()
            
            // Clamp the zoom factor to device limits
            let clampedFactor = max(device.minAvailableVideoZoomFactor, 
                                   min(factor, device.maxAvailableVideoZoomFactor))
            
            device.videoZoomFactor = clampedFactor
            currentZoomFactor = factor
            device.unlockForConfiguration()
        } catch {
            print("Error setting zoom: \(error)")
        }
    }
    
    private func switchToCamera(_ newCamera: AVCaptureDevice) {
        session.beginConfiguration()
        
        // Remove current input
        if let currentInput = videoDeviceInput {
            session.removeInput(currentInput)
        }
        
        // Add new input
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoDeviceInput = newInput
                currentCamera = newCamera
            }
        } catch {
            print("Error switching camera for zoom: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    private func updateAvailableZoomFactors() {
        guard let device = currentCamera else { return }
        
        var factors: [CGFloat] = []
        
        // Check for ultra wide camera (0.5x)
        if let _ = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            factors.append(0.5)
        }
        
        // Standard wide camera (1.0x)
        factors.append(1.0)
        
        // Check for telephoto camera or zoom capability
        if device.maxAvailableVideoZoomFactor >= 2.0 {
            factors.append(2.0)
        }
        
        // Some devices have 3x zoom
        if device.maxAvailableVideoZoomFactor >= 3.0 {
            factors.append(3.0)
        }
        
        DispatchQueue.main.async {
            self.availableZoomFactors = factors
        }
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }
    
    func startLiveAnalysis() {
        isAnalyzing = true
        frameCount = 0
        consecutiveFramesWithoutHammer = 0
        isActivelyTracking = false
        armRaisedStartTime = nil
        hammerTracker?.resetTracking()
        
        DispatchQueue.main.async {
            self.poseDetectionStatus = "Arm heben zum Start"
        }
    }
    
    func stopLiveAnalysis() {
        isAnalyzing = false
        isActivelyTracking = false
        isDetectingPose = false
        armRaisedStartTime = nil
        
        DispatchQueue.main.async {
            self.poseDetectionStatus = "Analyse gestoppt"
        }
    }
    
    private func completeAnalysis() {
        isActivelyTracking = false
        armRaisedStartTime = nil
        
        // Perform trajectory analysis
        if let analysis = hammerTracker?.analyzeTrajectory() {
            let resultsText = formatAnalysisResults(analysis)
            
            DispatchQueue.main.async {
                self.poseDetectionStatus = "Analyse abgeschlossen"
                self.onAnalysisComplete?(resultsText)
                
                // Speak results
                self.speakResults(resultsText)
                
                // Reset for next detection
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.poseDetectionStatus = "Arm heben zum Start"
                    self.hammerTracker?.resetTracking()
                }
            }
        } else {
            DispatchQueue.main.async {
                self.poseDetectionStatus = "Keine vollständige Trajektorie erkannt"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.poseDetectionStatus = "Arm heben zum Start"
                }
            }
        }
    }
    
    private func formatAnalysisResults(_ analysis: TrajectoryAnalysis) -> String {
        var results = ""
        
        for (index, ellipse) in analysis.ellipses.enumerated() {
            let direction = ellipse.angle > 0 ? "rechts" : "links"
            let absAngle = abs(ellipse.angle)
            results += "Drehung \(index + 3): \(String(format: "%.1f", absAngle)) Grad nach \(direction)\n"
        }
        
        results += "\nDurchschnitt: \(String(format: "%.1f", abs(analysis.averageAngle))) Grad"
        
        return results
    }
    
    private func speakResults(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        
        speechSynthesizer.speak(utterance)
    }
    
    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
        // Configure flash for photo capture (would need photo output for actual implementation)
    }
    
    func switchCamera() {
        session.beginConfiguration()
        
        // Remove current input
        if let input = videoDeviceInput {
            session.removeInput(input)
        }
        
        // Get new camera
        let position: AVCaptureDevice.Position = currentCamera?.position == .back ? .front : .back
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            session.commitConfiguration()
            return
        }
        
        // Add new input
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoDeviceInput = newInput
                currentCamera = newCamera
            }
        } catch {
            print("Error switching camera: \(error)")
        }
        
        session.commitConfiguration()
    }
}

// AVCaptureVideoDataOutputSampleBufferDelegate for live processing
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        frameCount += 1
        
        // Run pose detection if analyzing but not actively tracking
        if isAnalyzing && !isActivelyTracking && poseRequest != nil {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            do {
                try handler.perform([poseRequest!])
            } catch {
                print("Failed to perform pose detection: \(error)")
            }
        }
        
        // Process hammer detection if actively tracking
        if isActivelyTracking {
            let previousFrameCount = hammerTracker?.currentTrajectory?.frames.count ?? 0
            
            // Process frame with hammer tracker
            hammerTracker?.processLiveFrame(pixelBuffer, frameNumber: frameCount)
            
            let currentFrameCount = hammerTracker?.currentTrajectory?.frames.count ?? 0
            
            // Check if hammer was detected in this frame
            if currentFrameCount > previousFrameCount {
                // Hammer detected, reset counter
                consecutiveFramesWithoutHammer = 0
            } else {
                // No hammer detected
                consecutiveFramesWithoutHammer += 1
                
                DispatchQueue.main.async {
                    self.framesWithoutHammer = self.consecutiveFramesWithoutHammer
                }
                
                // Check if we should stop analysis
                if consecutiveFramesWithoutHammer >= maxFramesWithoutHammer {
                    print("No hammer detected for \(maxFramesWithoutHammer) frames, completing analysis")
                    DispatchQueue.main.async {
                        self.completeAnalysis()
                    }
                }
            }
        }
    }
}

// Camera Preview with tap to focus
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: ((CGPoint) -> Void)?
    
    init(session: AVCaptureSession, onTap: ((CGPoint) -> Void)? = nil) {
        self.session = session
        self.onTap = onTap
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoRotationAngle = 90.0
        
        view.layer.addSublayer(previewLayer)
        
        // Store preview layer reference
        context.coordinator.previewLayer = previewLayer
        
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                layer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }
    
    class Coordinator: NSObject {
        let onTap: ((CGPoint) -> Void)?
        weak var previewLayer: AVCaptureVideoPreviewLayer?
        
        init(onTap: ((CGPoint) -> Void)?) {
            self.onTap = onTap
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            
            // Convert to device coordinates if preview layer exists
            if let previewLayer = previewLayer {
                let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
                // Pass the UI location for the indicator
                onTap?(location)
                
                // Find camera manager through responder chain and set focus
                if let window = gesture.view?.window,
                   let rootViewController = window.rootViewController,
                   let cameraManager = findCameraManager(in: rootViewController) {
                    cameraManager.setFocus(at: devicePoint)
                }
            } else {
                onTap?(location)
            }
        }
        
        private func findCameraManager(in viewController: UIViewController) -> CameraManager? {
            // This is a simplified approach - in production, you'd use a proper delegate pattern
            return nil
        }
    }
}
// Focus Indicator View
struct FocusIndicatorView: View {
    @State private var animating = false
    
    var body: some View {
        Rectangle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 80, height: 80)
            .scaleEffect(animating ? 0.8 : 1.0)
            .opacity(animating ? 0.8 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3)) {
                    animating = true
                }
            }
    }
}
