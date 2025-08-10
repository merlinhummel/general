import SwiftUI
import AVFoundation
import Vision
import Speech
import AudioToolbox

struct LiveView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isAnalysisMode = false
    @State private var showAnalysisResults = false
    @State private var analysisResultText = ""
    @StateObject private var hammerTracker = HammerTracker()
    @State private var showFocusIndicator = false
    @State private var focusLocation = CGPoint.zero
    @Environment(\.presentationMode) var presentationMode
    
    // Analysis mode selection
    @State private var showAnalysisOptions = false
    @State private var selectedAnalysisMode: AnalysisMode = .trajectory
    
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
                if cameraManager.isCameraReady {
                    CameraPreviewFixed(session: cameraManager.session, onTap: { location in
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
                } else {
                    // Show loading or black screen with indicator
                    ZStack {
                        Color.black
                            .ignoresSafeArea(edges: .bottom)
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Kamera wird initialisiert...")
                                .foregroundColor(.white)
                                .font(.caption)
                        }
                    }
                }
                
                // Focus indicator
                if showFocusIndicator && cameraManager.isCameraReady {
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
                        
                        // Show current analysis mode
                        Text("Modus: \(selectedAnalysisMode.rawValue)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                        
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
                        Button(action: { showAnalysisOptions = true }) {
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
                        .disabled(!cameraManager.isCameraReady)
                        .opacity(cameraManager.isCameraReady ? 1.0 : 0.6)
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
            print("📱 LiveView appeared - initializing camera...")
            
            // Setup the tracker and analysis mode
            cameraManager.hammerTracker = hammerTracker
            cameraManager.analysisMode = selectedAnalysisMode
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
            
            // Start camera immediately
            cameraManager.checkPermissions()
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
        .overlay(
            // Analysis Options Modal
            Group {
                if showAnalysisOptions {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showAnalysisOptions = false
                        }
                    
                    AnalysisOptionsView(
                        selectedMode: $selectedAnalysisMode,
                        showOptions: $showAnalysisOptions,
                        onStart: startAnalysis
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(), value: showAnalysisOptions)
        )
    }
    
    private func startAnalysis() {
        withAnimation {
            isAnalysisMode = true
            cameraManager.analysisMode = selectedAnalysisMode
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

// Camera Manager with Pose Detection - KRITISCHER FIX VERSION
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
    @Published var isCameraReady = false
    
    // Analysis mode
    var analysisMode: AnalysisMode = .trajectory
    
    private var output = AVCaptureMovieFileOutput()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var currentCamera: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    // KRITISCH: Dedizierte Queue für alle Session-Operationen
    private let sessionQueue = DispatchQueue(label: "SessionQueue", qos: .userInitiated)
    
    // Background processing queues for threading improvements  
    private let visionProcessingQueue = DispatchQueue(label: "VisionProcessing", qos: .userInitiated, attributes: .concurrent)
    private let hammerTrackingQueue = DispatchQueue(label: "HammerTracking", qos: .userInitiated, attributes: .concurrent)
    
    weak var hammerTracker: HammerTracker?
    private var frameCount = 0
    private var isAnalyzing = false
    
    // Frame throttling for performance
    private var frameProcessingCounter = 0
    private let frameProcessingInterval = 3 // Process every 3rd frame to reduce load
    private var lastUIUpdateTime: TimeInterval = 0
    private let uiUpdateInterval: TimeInterval = 0.2 // Update UI every 200ms max
    
    // Pose Detection
    private var poseRequest: VNDetectHumanBodyPoseRequest?
    private var lastArmPosition: VNRecognizedPoint?
    private var armRaisedStartTime: Date?
    private let armRaisedThreshold: TimeInterval = 0.2 // Arm muss 0.2 Sekunden gehoben bleiben
    
    // Pose Analyzer for knee angles
    private let poseAnalyzer = PoseAnalyzer()
    
    // Analysis tracking
    private var consecutiveFramesWithoutHammer = 0
    private let maxFramesWithoutHammer = 7
    private var analysisStartFrame = 0
    
    // Audio
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // Callback for analysis results
    var onAnalysisComplete: ((String) -> Void)?
    
    override init() {
        super.init()
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
        // Process pose for knee angles if needed
        if analysisMode == .kneeAngle || analysisMode == .both {
            let poseResult = poseAnalyzer.processPoseObservation(
                observation, 
                frameNumber: frameCount, 
                timestamp: Date().timeIntervalSince1970
            )
            
            // Debug output every 30 frames (disabled for performance)
            // if frameCount % 30 == 0 && (poseResult.leftKneeAngle != nil || poseResult.rightKneeAngle != nil) {
            //     print("Knee angles - Left: \(poseResult.leftKneeAngle ?? -1), Right: \(poseResult.rightKneeAngle ?? -1)")
            // }
        }
        
        // Check for arm raised (for trajectory analysis)
        if analysisMode == .trajectory || analysisMode == .both {
            do {
                // Get right wrist position (kann auch left wrist nehmen)
                let rightWrist = try observation.recognizedPoint(.rightWrist)
                let rightElbow = try observation.recognizedPoint(.rightElbow)
                let rightShoulder = try observation.recognizedPoint(.rightShoulder)
                
                // Debug output every 30 frames (disabled for performance)
                // if frameCount % 30 == 0 {
                //     print("Pose detection - Wrist: \(rightWrist.y), Elbow: \(rightElbow.y), Shoulder: \(rightShoulder.y), Confidence: \(rightWrist.confidence)")
                // }
                
                // FIXED: In Vision coordinates, Y=0 is top, Y=1 is bottom
                // So for arm raised: wrist.y < elbow.y < shoulder.y
                let isArmRaised = rightWrist.y < rightElbow.y && rightElbow.y < rightShoulder.y && rightWrist.confidence > 0.3
                
                // Throttled UI updates for pose detection
                let currentTime = CACurrentMediaTime()
                if currentTime - lastUIUpdateTime >= uiUpdateInterval {
                    lastUIUpdateTime = currentTime
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        if isArmRaised && !self.isActivelyTracking && self.isAnalyzing {
                            // Arm is raised
                            if self.armRaisedStartTime == nil {
                                self.armRaisedStartTime = Date()
                                self.isDetectingPose = true
                                self.poseDetectionStatus = "Arm erkannt - halte Position..."
                                
                                // Play detection sound
                                AudioServicesPlaySystemSound(1103) // Tock sound
                                print("Arm raised detected! Playing sound...")
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
                }
                
                self.lastArmPosition = rightWrist
                
            } catch {
                // Pose points not available
            }
        }
    }
    
    private func startTrackingHammer() {
        self.isActivelyTracking = true
        self.isDetectingPose = false
        self.poseDetectionStatus = "Hammer-Tracking läuft..."
        self.consecutiveFramesWithoutHammer = 0
        self.analysisStartFrame = self.frameCount
        
        // Reset hammer tracker and pose analyzer
        self.hammerTracker?.resetTracking()
        self.poseAnalyzer.reset()
        
        // Play start sound - louder and more distinctive
        AudioServicesPlaySystemSound(1117) // Begin Video Recording sound
        
        print("Started hammer tracking at frame \(self.frameCount)")
    }

    
    func checkPermissions() {
        print("📷 Checking camera permissions...")
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            print("✅ Camera permission already authorized")
            // Start camera setup immediately
            self.setupAndStartCamera()
        case .notDetermined:
            print("⚠️ Camera permission not determined, requesting...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    print("✅ Camera permission granted by user")
                    self?.setupAndStartCamera()
                } else {
                    print("❌ Camera permission denied by user")
                    DispatchQueue.main.async {
                        self?.showAlert = true
                        self?.isCameraReady = true // Show UI even without permission
                    }
                }
            }
        case .denied, .restricted:
            print("❌ Camera permission denied or restricted")
            DispatchQueue.main.async {
                self.showAlert = true
                self.isCameraReady = true // Show UI even without permission
            }
        @unknown default:
            print("❌ Unknown camera permission status")
            DispatchQueue.main.async {
                self.showAlert = true
                self.isCameraReady = true // Show UI even without permission
            }
        }
    }
    
    // KRITISCHER FIX: Diese Methode behebt den 1.02s Hang!
    private func setupAndStartCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("🔧 Setting up camera session...")
            
            // WICHTIG: Setze isCameraReady früh, damit UI nicht blockiert
            DispatchQueue.main.async {
                self.isCameraReady = true
                print("✅ Camera ready flag set early for UI")
            }
            
            // Begin configuration
            self.session.beginConfiguration()
            
            // Remove all existing inputs and outputs
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            
            // Set session preset
            if self.session.canSetSessionPreset(.hd1920x1080) {
                self.session.sessionPreset = .hd1920x1080
                print("✅ Session preset set to HD 1920x1080")
            } else if self.session.canSetSessionPreset(.high) {
                self.session.sessionPreset = .high
                print("✅ Session preset set to high")
            }
            
            // Configure camera input
            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                do {
                    let input = try AVCaptureDeviceInput(device: camera)
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                        self.videoDeviceInput = input
                        self.currentCamera = camera
                        print("✅ Camera input added")
                    }
                    
                    // Configure camera settings
                    try camera.lockForConfiguration()
                    
                    // Auto-focus configuration
                    if camera.isFocusModeSupported(.continuousAutoFocus) {
                        camera.focusMode = .continuousAutoFocus
                        print("✅ Continuous auto-focus enabled")
                    }
                    
                    // Auto-exposure configuration
                    if camera.isExposureModeSupported(.continuousAutoExposure) {
                        camera.exposureMode = .continuousAutoExposure
                        print("✅ Continuous auto-exposure enabled")
                    }
                    
                    // Frame rate configuration for smooth performance
                    let targetFrameRate: Int32 = 30
                    camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: targetFrameRate)
                    camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: targetFrameRate)
                    print("✅ Frame rate set to \(targetFrameRate) FPS")
                    
                    camera.unlockForConfiguration()
                    
                    // Add video data output
                    self.videoDataOutput = AVCaptureVideoDataOutput()
                    self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
                    self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                    self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
                    
                    if self.session.canAddOutput(self.videoDataOutput) {
                        self.session.addOutput(self.videoDataOutput)
                        print("✅ Video output added")
                        
                        // Configure video connection
                        if let connection = self.videoDataOutput.connection(with: .video) {
                            connection.isEnabled = true
                            
                            // Set video orientation based on iOS version
                            if #available(iOS 17.0, *) {
                                if connection.isVideoRotationAngleSupported(90) {
                                    connection.videoRotationAngle = 90
                                    print("✅ Video rotation set to 90 degrees (iOS 17+)")
                                }
                            } else {
                                if connection.isVideoOrientationSupported {
                                    connection.videoOrientation = .portrait
                                    print("✅ Video orientation set to portrait")
                                }
                            }
                            
                            // Ensure connection is active
                            connection.isEnabled = true
                            print("✅ Video connection configured and enabled")
                        }
                    }
                } catch {
                    print("❌ Camera setup error: \(error)")
                }
            } else {
                print("❌ No camera device found - running in Simulator or camera not available")
                // Still mark as ready to show UI even without camera
                DispatchQueue.main.async {
                    self.isCameraReady = true
                    self.poseDetectionStatus = "Keine Kamera verfügbar"
                }
            }
            
            // Commit configuration
            self.session.commitConfiguration()
            print("✅ Session configuration committed")
            
            // Update zoom factors
            self.updateAvailableZoomFactors()
            
            // KRITISCHER FIX: Session Start auf separatem Thread!
            // Dies verhindert den Deadlock und den 1.02s Hang
            DispatchQueue.global(qos: .userInitiated).async {
                print("🚀 Starting session on userInitiated queue...")
                
                // Session sofort starten
                self.session.startRunning()
                
                // Verify status und update UI
                DispatchQueue.main.async {
                    let isRunning = self.session.isRunning
                    print(isRunning ? "✅ Session is running successfully!" : "⚠️ Session failed to start")
                    
                    // Update camera ready status based on actual running state
                    if isRunning {
                        self.isCameraReady = true
                        print("✅ Camera fully operational")
                    } else {
                        // Retry once if failed
                        print("⚠️ Retrying session start...")
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3) {
                            self.session.startRunning()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                if self.session.isRunning {
                                    print("✅ Session started on retry!")
                                    self.isCameraReady = true
                                } else {
                                    print("❌ Session failed to start after retry")
                                    // Still set ready to show UI, even if preview is black
                                    self.isCameraReady = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func startSession() {
        print("🚀 Starting camera session manually...")
        
        guard !session.isRunning else {
            print("✅ Session already running")
            DispatchQueue.main.async {
                self.isCameraReady = true
            }
            return
        }
        
        // Set ready flag early for UI
        DispatchQueue.main.async {
            self.isCameraReady = true
        }
        
        // Start session on appropriate queue
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.startRunning()
            
            DispatchQueue.main.async {
                if self.session.isRunning {
                    print("✅ Camera session started successfully")
                } else {
                    print("⚠️ Camera session failed to start")
                }
            }
        }
    }
    
    func stopSession() {
        print("📴 Stopping camera session...")
        
        DispatchQueue.main.async {
            self.isCameraReady = false
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.session.isRunning {
                self.session.stopRunning()
                print("✅ Camera session stopped successfully")
            } else {
                print("⚠️ Session was not running")
            }
        }
    }
    
    // Rest of the methods remain the same...
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
        
        do {
            try device.lockForConfiguration()
            
            let clampedFactor = max(device.minAvailableVideoZoomFactor, 
                                   min(factor, device.maxAvailableVideoZoomFactor))
            
            device.videoZoomFactor = clampedFactor
            currentZoomFactor = factor
            device.unlockForConfiguration()
        } catch {
            print("Error setting zoom: \(error)")
        }
    }
    
    private func updateAvailableZoomFactors() {
        guard let device = currentCamera else { return }
        
        var factors: [CGFloat] = [1.0]
        
        if device.maxAvailableVideoZoomFactor >= 2.0 {
            factors.append(2.0)
        }
        
        if device.maxAvailableVideoZoomFactor >= 3.0 {
            factors.append(3.0)
        }
        
        DispatchQueue.main.async {
            self.availableZoomFactors = factors
        }
    }
    
    func startLiveAnalysis() {
        isAnalyzing = true
        frameCount = 0
        consecutiveFramesWithoutHammer = 0
        isActivelyTracking = false
        armRaisedStartTime = nil
        hammerTracker?.resetTracking()
        poseAnalyzer.reset()
        
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
        
        var resultsText = ""
        
        if analysisMode == .trajectory || analysisMode == .both {
            if let analysis = hammerTracker?.analyzeTrajectory() {
                resultsText += formatAnalysisResults(analysis)
            } else {
                resultsText += "Keine vollständige Trajektorie erkannt.\n"
            }
        }
        
        if analysisMode == .kneeAngle || analysisMode == .both {
            if analysisMode == .both {
                resultsText += "\n\n"
            }
            resultsText += poseAnalyzer.formatKneeAngleResults()
        }
        
        DispatchQueue.main.async {
            self.poseDetectionStatus = "Analyse abgeschlossen"
            self.onAnalysisComplete?(resultsText)
            
            self.speakResults(resultsText)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.poseDetectionStatus = "Arm heben zum Start"
                self.hammerTracker?.resetTracking()
                self.poseAnalyzer.reset()
            }
        }
    }
    
    private func formatAnalysisResults(_ analysis: TrajectoryAnalysis) -> String {
        var results = "Trajektorien-Analyse:\n\n"
        
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
    }
    
    func switchCamera() {
        session.beginConfiguration()
        
        if let input = videoDeviceInput {
            session.removeInput(input)
        }
        
        let position: AVCaptureDevice.Position = currentCamera?.position == .back ? .front : .back
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            session.commitConfiguration()
            return
        }
        
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
        updateAvailableZoomFactors()
    }
}

// Extension for AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        frameCount += 1
        frameProcessingCounter += 1
        
        if frameCount % 30 == 0 {
            print("Frame \(frameCount) received. Analyzing: \(isAnalyzing), Tracking: \(isActivelyTracking)")
        }
        
        guard frameProcessingCounter >= frameProcessingInterval else { return }
        frameProcessingCounter = 0
        
        if isAnalyzing && poseRequest != nil {
            visionProcessingQueue.async { [weak self] in
                guard let self = self else { return }
                
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
                do {
                    try handler.perform([self.poseRequest!])
                } catch {
                    print("Failed to perform pose detection: \(error)")
                }
            }
        }
        
        if isActivelyTracking && (analysisMode == .trajectory || analysisMode == .both) {
            let currentFrameCount = frameCount
            
            hammerTrackingQueue.async { [weak self] in
                guard let self = self else { return }
                
                let previousFrameCount = self.hammerTracker?.currentTrajectory?.frames.count ?? 0
                
                self.hammerTracker?.processLiveFrame(pixelBuffer, frameNumber: currentFrameCount)
                
                let newFrameCount = self.hammerTracker?.currentTrajectory?.frames.count ?? 0
                
                if newFrameCount > previousFrameCount {
                    self.consecutiveFramesWithoutHammer = 0
                } else {
                    self.consecutiveFramesWithoutHammer += 1
                    
                    let currentTime = CACurrentMediaTime()
                    if currentTime - self.lastUIUpdateTime >= self.uiUpdateInterval {
                        self.lastUIUpdateTime = currentTime
                        let currentCount = self.consecutiveFramesWithoutHammer
                        
                        DispatchQueue.main.async {
                            self.framesWithoutHammer = currentCount
                        }
                    }
                    
                    if self.consecutiveFramesWithoutHammer >= self.maxFramesWithoutHammer {
                        print("No hammer detected for \(self.maxFramesWithoutHammer) frames, completing analysis")
                        DispatchQueue.main.async {
                            self.completeAnalysis()
                        }
                    }
                }
            }
        }
    }
}

// Rest of the UI components remain the same...
struct CameraPreviewFixed: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: ((CGPoint) -> Void)?
    
    func makeUIView(context: Context) -> UIView {
        print("🎥 Creating camera preview view...")
        let view = CameraPreviewView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        // Ensure connection is properly configured
        if let connection = previewLayer.connection {
            connection.isEnabled = true
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            print("✅ Preview layer connection configured")
        } else {
            print("⚠️ No preview layer connection available yet")
        }
        
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        context.coordinator.previewLayer = previewLayer
        
        // Add tap gesture for focus
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        print("✅ Camera preview view created successfully")
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Check if session is running when view updates
        if session.isRunning {
            print("✅ Session is running in preview update")
        } else {
            print("⚠️ Session not running in preview update")
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
            
            if let previewLayer = previewLayer {
                let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
                onTap?(location)
            } else {
                onTap?(location)
            }
        }
    }
}

class CameraPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

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
