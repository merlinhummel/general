import SwiftUI
import AVFoundation
import Vision
import Speech
import AudioToolbox
import Metal

struct LiveView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var isAnalysisMode = false
    @StateObject private var hammerTracker = HammerTracker()
    @State private var showFocusIndicator = false
    @State private var focusLocation = CGPoint.zero
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Main content area with camera (fullscreen)
            ZStack {
                // Camera Preview with tap to focus
                if cameraManager.isCameraReady {
                    CameraPreviewFixed(session: cameraManager.session, onTap: { screenPoint, devicePoint in
                        focusLocation = screenPoint
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFocusIndicator = true
                        }
                        cameraManager.setFocus(at: devicePoint)

                        // Hide focus indicator after a moment
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showFocusIndicator = false
                            }
                        }
                    })
                    .ignoresSafeArea()
                } else {
                    // Show loading or black screen with indicator
                    ZStack {
                        Color.black
                            .ignoresSafeArea()
                        
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

                // Pose Skeleton Overlay
                if cameraManager.isPoseDetectionEnabled, let pose = cameraManager.detectedPose {
                    PoseSkeletonView(observation: pose, isFrontCamera: cameraManager.isFrontCamera)
                        .allowsHitTesting(false)
                }

                // Hammer Bounding Box Overlay (DIREKT vom CameraManager wie Pose Detection)
                if let boundingBox = cameraManager.detectedHammerBox {
                    HammerBoundingBoxView(boundingBox: boundingBox, isFrontCamera: cameraManager.isFrontCamera)
                        .allowsHitTesting(false)
                }

                // 🧪 Torso Angle Overlay (oben mittig)
                if let torsoAngle = cameraManager.currentTorsoAngle {
                    VStack {
                        TorsoAngleView(angle: torsoAngle)
                            .padding(.top, 80)
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
            }

            // Overlay: Floating UI Elements
            VStack(spacing: 0) {
                // Floating Header Buttons (like SingleView)
                HStack {
                    // Back button
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
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .liquidGlassEffect(style: .thin, cornerRadius: 12)
                    }

                    Spacer()

                    // Title
                    Text("Live View")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .liquidGlassEffect(style: .thin, cornerRadius: 12)

                    Spacer()

                    // Placeholder for balance
                    Color.clear
                        .frame(width: 80, height: 20)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .padding(.top, 0)

                Spacer()

                // Bottom Controls with Liquid Glass
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
                        .interactiveLiquidGlass(cornerRadius: 25)
                    }
                    .disabled(!cameraManager.isCameraReady)
                    .opacity(cameraManager.isCameraReady ? 1.0 : 0.6)
                    .padding(.bottom, 20)
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
                    .padding(.bottom, 20)
                }

                // Camera Controls Panel (same style as SingleView VideoControlsView)
                CameraControlsView(cameraManager: cameraManager)
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .frame(maxHeight: .infinity, alignment: .top)  // VStack nimmt volle Höhe ein, Elemente oben ausgerichtet
            .ignoresSafeArea(edges: .bottom)  // Ignoriere Safe Area unten, damit 20px wirklich zum physischen Bildschirmrand sind
        }
        .navigationBarHidden(true)
        .onAppear {
            print("📱 LiveView appeared - initializing camera...")

            // Setup the tracker and analysis mode (nur trajectory, kein knee angle)
            cameraManager.hammerTracker = hammerTracker
            cameraManager.analysisMode = .trajectory

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
    }

    private func startAnalysis() {
        withAnimation {
            isAnalysisMode = true
            cameraManager.analysisMode = .trajectory  // Nur Ellipsen-Winkel
            cameraManager.startLiveAnalysis()
        }
    }
    
    private func stopAnalysis() {
        withAnimation {
            isAnalysisMode = false
            cameraManager.stopLiveAnalysis()
        }
    }
}

// Camera Manager with Pose Detection - KRITISCHER FIX VERSION
class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var showAlert = false
    @Published var isTorchOn = false  // Taschenlampe (für Live-Kamera)
    @Published var isDetectingPose = false
    @Published var isActivelyTracking = false
    @Published var poseDetectionStatus = "Warte auf Arm-Bewegung..."
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var availableZoomFactors: [CGFloat] = [1.0]
    @Published var isCameraReady = false
    @Published var isFrontCamera = false  // Track if front camera is active

    // Pose visualization
    @Published var detectedPose: VNHumanBodyPoseObservation?
    @Published var isPoseDetectionEnabled: Bool = true

    // Hammer detection visualization (DIREKT wie Pose-Detection)
    @Published var detectedHammerBox: CGRect?
    private var hammerDetectionModel: VNCoreMLModel?

    // 🧪 Torso Angle Display
    @Published var currentTorsoAngle: Double?

    // Analysis mode (nur trajectory für Ellipsen-Winkel)
    var analysisMode: AnalysisMode = .trajectory
    
    private var output = AVCaptureMovieFileOutput()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var currentCamera: AVCaptureDevice?
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)

    // 📷 Adaptive Multi-Kamera Support
    // Dictionary: Zoom-Faktor → Kamera-Device (0.5x → Ultra Wide, 1.0x → Wide Angle, 2x → Telephoto, etc.)
    private var availableCameras: [CGFloat: AVCaptureDevice] = [:]
    private var cameraZoomFactors: [CGFloat] = []
    
    // KRITISCH: Dedizierte Queue für alle Session-Operationen
    private let sessionQueue = DispatchQueue(label: "SessionQueue", qos: .userInitiated)
    
    // Background processing queues for threading improvements  
    private let visionProcessingQueue = DispatchQueue(label: "VisionProcessing", qos: .userInitiated, attributes: .concurrent)
    private let hammerTrackingQueue = DispatchQueue(label: "HammerTracking", qos: .userInitiated, attributes: .concurrent)
    
    weak var hammerTracker: HammerTracker?
    private var frameCount = 0
    @Published var isAnalyzing = false
    
    // Frame throttling for performance
    private var frameProcessingCounter = 0
    private let frameProcessingInterval = 1 // Process EVERY frame for 60 FPS analysis
    private var lastUIUpdateTime: TimeInterval = 0
    private let uiUpdateInterval: TimeInterval = 0.2 // Update UI every 200ms max
    private var lastDebugLogTime: TimeInterval = 0
    private let debugLogInterval: TimeInterval = 0.5 // Debug log every 500ms max

    // 🔥 CRITICAL FIX: Frame throttling für Pose Detection während Tracking
    private var poseFrameCounter = 0
    private let poseProcessingInterval = 3 // Process every 3rd frame during tracking = ~20 FPS

    // Pose Detection
    private var poseRequest: VNDetectHumanBodyPoseRequest?
    private var lastArmPosition: VNRecognizedPoint?
    private var armRaisedStartTime: Date?
    private let armRaisedThreshold: TimeInterval = 0.2 // Arm muss 0.2 Sekunden gehoben bleiben

    // 🧪 Torso Angle Logging (für Testing)
    private var torsoAngleLogCounter = 0
    private let torsoAngleLogInterval = 10 // Log alle 10 Frames (~6x pro Sekunde bei 60 FPS)

    // Pose Analyzer for knee angles
    private let poseAnalyzer = PoseAnalyzer()

    // Analysis tracking
    private var analysisStartFrame = 0

    // ⏱️ Timeout: Analyse beenden nach 1 Sekunde (60 Frames) ohne Hammer
    private var framesWithoutHammer = 0
    private let maxFramesWithoutHammer = 60

    // Audio
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var isSpeaking = false
    private var cachedVoice: AVSpeechSynthesisVoice?

    override init() {
        super.init()
        setupPoseDetection()
        setupHammerDetection()

        // Setup speech synthesizer delegate
        speechSynthesizer.delegate = self

        // 🔊 AUDIO SESSION AKTIVIEREN - FIX FÜR 5 SEKUNDEN VERZÖGERUNG!
        // Aktiviere Audio-Session SOFORT damit TTS ohne Delay abspielbar ist
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
            print("🔊 AVAudioSession activated for instant TTS playback")
        } catch {
            print("⚠️ Failed to activate audio session: \(error)")
        }

        // 🎙️ Cache voice selection EINMALIG beim Init (nicht bei jedem TTS-Call!)
        let allGermanVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: "de") }
        if let premiumVoice = allGermanVoices.first(where: { $0.quality == .premium }) {
            cachedVoice = premiumVoice
            print("🎙️ Cached PREMIUM German voice: \(premiumVoice.name)")
        } else if let enhancedVoice = allGermanVoices.first(where: { $0.quality == .enhanced }) {
            cachedVoice = enhancedVoice
            print("🎙️ Cached ENHANCED German voice: \(enhancedVoice.name)")
        } else {
            cachedVoice = AVSpeechSynthesisVoice(language: "de-DE")
            print("🎙️ Cached DEFAULT German voice")
        }

        // 🔥 TTS WARMUP - Lädt Voice und initialisiert TTS-Engine im Hintergrund
        // Dies verhindert die 10-Sekunden-Verzögerung beim ersten echten TTS-Call!
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            print("🔥 TTS WARMUP: Starting voice preload...")
            let warmupUtterance = AVSpeechUtterance(string: " ") // Leeres Space
            warmupUtterance.voice = self.cachedVoice
            warmupUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
            warmupUtterance.volume = 0.01 // Fast unhörbar (1% Lautstärke)

            self.speechSynthesizer.speak(warmupUtterance)
            print("🔥 TTS WARMUP: Voice preload utterance spoken (silent)")
        }
    }

    private func setupHammerDetection() {
        // Load NANO CoreML model mit 640x640 input für optimierte Live-Detection
        // 🚀 KRITISCHE OPTIMIERUNGEN für 60 FPS:
        // 1. Neural Engine aktiviert (.all statt .cpuAndGPU)
        // 2. Metal Device Optimization
        // 3. 640x640 Input (statt 1024x1024)
        guard let modelURL = Bundle.main.url(forResource: "bestnano640", withExtension: "mlpackage") ??
                             Bundle.main.url(forResource: "bestnano640", withExtension: "mlmodelc") else {
            print("❌ Hammer detection NANO 640 model not found")
            return
        }

        do {
            // 🔥 FIX 1: Nutze Neural Engine + GPU + CPU (statt nur CPU+GPU)
            let config = MLModelConfiguration()
            config.computeUnits = .all  // ⚡ Aktiviert Neural Engine!

            // 🔥 FIX 2: Metal Device Optimization für maximale GPU Performance
            if let metalDevice = MTLCreateSystemDefaultDevice() {
                config.preferredMetalDevice = metalDevice
                print("✅ Metal device optimization enabled")
            }

            let model = try MLModel(contentsOf: modelURL, configuration: config)
            hammerDetectionModel = try VNCoreMLModel(for: model)

            print("🚀 PERFORMANCE MODE: Hammer detection NANO 640x640 loaded")
            print("   ⚡ Neural Engine: ACTIVATED")
            print("   🎯 Metal Device: OPTIMIZED")
            print("   📐 Input: 640x640 (4.9 MiB)")
            print("   🎯 Target: ~10-15ms inference (60+ FPS capable)")
            print("   💾 Memory: ~180 MiB peak (optimized)")
        } catch {
            print("❌ Failed to load hammer detection model: \(error)")
        }
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
        // Update detected pose for visualization (IMMER wenn enabled, auch während Tracking!)
        if isPoseDetectionEnabled {
            DispatchQueue.main.async { [weak self] in
                self?.detectedPose = observation
            }
        }

        // 🧪 TESTING: Kontinuierliche Berechnung des Oberkörper-Winkels (IMMER wenn Pose Detection aktiv)
        if isPoseDetectionEnabled {
            torsoAngleLogCounter += 1

            if torsoAngleLogCounter >= torsoAngleLogInterval {
                torsoAngleLogCounter = 0

                // Berechne Torso-Winkel und update UI
                let torsoAngle = calculateTorsoAngle(observation: observation)

                DispatchQueue.main.async { [weak self] in
                    self?.currentTorsoAngle = torsoAngle
                }
            }
        }

        // Check for arm angle ONLY when NOT tracking (während Tracking: nur Visualisierung)
        if isPoseDetectionEnabled && !isActivelyTracking && isAnalyzing && (analysisMode == .trajectory || analysisMode == .both) {
            do {
                // Hole beide Arme für Winkel-Prüfung
                let rightElbow = try observation.recognizedPoint(.rightElbow)
                let rightShoulder = try observation.recognizedPoint(.rightShoulder)
                let leftElbow = try observation.recognizedPoint(.leftElbow)
                let leftShoulder = try observation.recognizedPoint(.leftShoulder)

                // Berechne Oberarm-Winkel zur Vertikalen (Schulter → Ellenbogen)
                let rightArmAngle = calculateUpperArmAngle(shoulder: rightShoulder, elbow: rightElbow)
                let leftArmAngle = calculateUpperArmAngle(shoulder: leftShoulder, elbow: leftElbow)

                // Prüfe ob EINER der Arme im Start-Range ist
                // Rechter Arm: 160-180° (horizontal zur Seite)
                // Linker Arm: 0-20° (horizontal zur Seite)
                let rightArmReady = rightArmAngle != nil &&
                                    rightArmAngle! >= 160 && rightArmAngle! <= 180 &&
                                    rightElbow.confidence > 0.2 && rightShoulder.confidence > 0.2

                let leftArmReady = leftArmAngle != nil &&
                                   leftArmAngle! >= 0 && leftArmAngle! <= 20 &&
                                   leftElbow.confidence > 0.2 && leftShoulder.confidence > 0.2

                let isStartPosition = rightArmReady || leftArmReady

                // 🔍 DEBUG: Nur loggen wenn interessant (Start-Position erkannt)
                if isStartPosition && !self.isDetectingPose {
                    print("📊 ARM DEBUG - START POSITION:")
                    print("   Right Shoulder: \(String(format: "%.2f", rightShoulder.confidence)) | Elbow: \(String(format: "%.2f", rightElbow.confidence))")
                    print("   Left Shoulder: \(String(format: "%.2f", leftShoulder.confidence)) | Elbow: \(String(format: "%.2f", leftElbow.confidence))")
                    if let rightAngle = rightArmAngle {
                        print("   Right arm: \(String(format: "%.1f", rightAngle))°")
                    }
                    if let leftAngle = leftArmAngle {
                        print("   Left arm: \(String(format: "%.1f", leftAngle))°")
                    }
                }

                // WICHTIG: Prüfung ERST im async Block für atomare Ausführung!
                if isStartPosition {
                    let detectedArm = rightArmReady ? "rechter" : "linker"
                    let angle = rightArmReady ? rightArmAngle! : leftArmAngle!

                    // Dispatch BEFORE checking flag - dann Check INSIDE für Atomarität
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }

                        // NOW check flag atomically on main thread!
                        guard !self.isDetectingPose else { return }

                        // Flag setzen + Tracking starten
                        self.isDetectingPose = true
                        self.poseDetectionStatus = "Arm erkannt - Tracking läuft!"

                        // Sound abspielen
                        AudioServicesPlaySystemSound(1117)

                        // Tracking starten
                        self.startTrackingHammer()

                        print("✅ Arm erkannt (\(detectedArm), \(String(format: "%.1f", angle))°) - Tracking gestartet")
                    }
                }

            } catch {
                print("⚠️ Pose points not available: \(error)")
            }
        }
    }

    /// Berechnet Oberarm-Winkel zur Vertikalen - NUR horizontale Komponente zählt
    /// - Parameters:
    ///   - shoulder: Schulter-Position
    ///   - elbow: Ellenbogen-Position
    /// - Returns: Winkel in Grad (0° = gerade runter, 90° = horizontal zur Seite), nil bei ungültigen Werten
    private func calculateUpperArmAngle(shoulder: VNRecognizedPoint, elbow: VNRecognizedPoint) -> Double? {
        // Prüfe Confidence
        guard shoulder.confidence > 0.2 && elbow.confidence > 0.2 else {
            return nil
        }

        // Vector: Schulter → Ellenbogen
        let dx = abs(elbow.location.x - shoulder.location.x)  // Horizontale Distanz (immer positiv)
        let dy = elbow.location.y - shoulder.location.y        // Vertikale Distanz (positiv = runter, negativ = hoch)

        // Prüfe auf minimale Bewegung
        guard dx > 0.001 || abs(dy) > 0.001 else {
            return nil
        }

        // Neue Logik: Nur horizontal zur Seite ausgestreckt = Trigger
        // Wenn dy positiv (Ellenbogen tiefer als Schulter) → Arm hängt runter → KEIN Trigger
        // Wenn dy negativ (Ellenbogen höher als Schulter) → Arm ist oben → kann triggern
        // Wenn dx groß → Arm zur Seite → kann triggern

        // Berechne Winkel mit atan2 (sicherer als acos!)
        // atan2(dx, dy) gibt uns den Winkel wobei:
        //   - dy > 0 (Arm nach unten) → kleiner Winkel
        //   - dy < 0 (Arm nach oben) → großer Winkel
        //   - dx groß (Arm zur Seite) → ~90°
        let angleRadians = atan2(dx, -dy)  // -dy weil Y nach unten positiv ist
        let angleDegrees = angleRadians * 180.0 / .pi

        // Clamp zu [0, 180]
        let clampedAngle = max(0, min(180, angleDegrees))

        return clampedAngle
    }

    /// Berechnet Oberkörper-Neigungswinkel (nach vorne/hinten)
    /// - Parameter observation: Die Pose-Observation
    /// - Returns: Winkel in Grad (positiv = nach vorne gebeugt, negativ = nach hinten gelehnt), nil bei ungültigen Werten
    ///
    /// **Verwendete Joints:**
    /// - `.root` (VNHumanBodyPoseObservation.JointName.root) - Unterer Rücken/Hüftmitte
    /// - `.neck` (VNHumanBodyPoseObservation.JointName.neck) - Nacken/Oberkörper-Anfang
    ///
    /// **Berechnung:**
    /// - Vektor: root → neck = Oberkörper-Achse
    /// - Vergleich mit Vertikale (Schwerkraft-Achse)
    /// - 0° = perfekt aufrecht
    /// - +30° = leicht nach vorne gebeugt
    /// - -15° = leicht nach hinten gelehnt
    private func calculateTorsoAngle(observation: VNHumanBodyPoseObservation) -> Double? {
        do {
            // Hole unterer Rücken (root) und Nacken (neck)
            let root = try observation.recognizedPoint(.root)
            let neck = try observation.recognizedPoint(.neck)

            // Prüfe Confidence (mindestens 0.2 für Testing - niedrige Schwelle)
            guard root.confidence > 0.2 && neck.confidence > 0.2 else {
                return nil
            }

            // Vektor: root → neck (Oberkörper-Achse)
            // Vision Koordinaten: (0,0) = unten links, (1,1) = oben rechts
            let dx = neck.location.x - root.location.x  // Horizontal (positiv = nach rechts)
            let dy = neck.location.y - root.location.y  // Vertikal (positiv = nach oben)

            // Prüfe auf minimale Bewegung
            guard abs(dx) > 0.001 || abs(dy) > 0.001 else {
                return nil
            }

            // Berechne Winkel zur Vertikalen mit atan2
            // atan2(dx, dy) gibt uns den Winkel des Oberkörpers zur Vertikalen
            //
            // WICHTIG: Vision orientation = .right bedeutet:
            // - Standing straight: neck ist "rechts" von root in Vision coords → dx groß, dy klein → ~90°
            // - Forward bend: dx wird kleiner → angle geht gegen 0°
            // - Backward lean: dx wird größer → angle geht über 90°
            //
            // Für Hammerwurf Konvention (benutzerfreundlich):
            // - 0° = perfekt aufrecht stehen
            // - Positiv = nach VORNE gebeugt (z.B. +30°)
            // - Negativ = nach HINTEN gelehnt (z.B. -15°)
            //
            // Umrechnung: adjustedAngle = 90° - rawAngle
            let angleRadians = atan2(dx, dy)
            let rawAngleDegrees = angleRadians * 180.0 / .pi

            // Konvertiere: 90° (straight) → 0°, <90° (forward) → positive, >90° (backward) → negative
            let adjustedAngle = 90.0 - rawAngleDegrees

            return adjustedAngle

        } catch {
            return nil
        }
    }

    private func startTrackingHammer() {
        self.isActivelyTracking = true
        // isDetectingPose bleibt true (verhindert weitere Trigger während Tracking)
        self.poseDetectionStatus = "Hammer-Tracking läuft..."
        self.analysisStartFrame = self.frameCount
        self.framesWithoutHammer = 0  // Reset timeout counter

        // Reset hammer tracker and pose analyzer
        self.hammerTracker?.resetTracking()
        self.poseAnalyzer.reset()

        print("⚡ Hammer tracking gestartet bei Frame \(self.frameCount)")
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
            
            // 🚀 HIGH RESOLUTION: 1920x1080 Full HD @ 60 FPS
            // iPhone 14 Pro Max unterstützt 1080p @ 60 FPS!
            // Video resolution unabhängig vom ML-Modell (bleibt 640x640)

            // Setze KEIN Preset - wir wählen das Format direkt!
            // Preset limitations können 60 FPS blockieren
            print("🔍 Searching for 1080p 60 FPS camera format...")

            // 📷 ADAPTIVE KAMERA-ERKENNUNG - Erkenne ALLE verfügbaren Kameras
            // Unterstützt: Ultra Wide (0.5x), Wide (1x), Telephoto (2x), Triple Camera, Dual Camera, etc.
            print("🔍 Erkenne verfügbare Kameras adaptiv...")

            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInUltraWideCamera,      // 0.5x (iPhone 11+)
                    .builtInWideAngleCamera,      // 1.0x (Standard)
                    .builtInTelephotoCamera,      // 2x-3x (iPhone 7 Plus+)
                    .builtInDualCamera,           // Dual-System (Wide + Telephoto)
                    .builtInTripleCamera,         // Triple-System (Ultra Wide + Wide + Telephoto)
                    .builtInDualWideCamera        // Dual Wide (Ultra Wide + Wide)
                ],
                mediaType: .video,
                position: .back
            )

            // Sammle alle verfügbaren Kameras und ordne sie ihrem nativen Zoom-Faktor zu
            for device in discoverySession.devices {
                let deviceName: String
                let nativeZoom: CGFloat

                switch device.deviceType {
                case .builtInUltraWideCamera:
                    deviceName = "Ultra Wide"
                    nativeZoom = 0.5
                case .builtInWideAngleCamera:
                    deviceName = "Wide Angle"
                    nativeZoom = 1.0
                case .builtInTelephotoCamera:
                    deviceName = "Telephoto"
                    nativeZoom = 2.0  // Kann auch 3x sein, wird durch Format-Check verfeinert
                case .builtInDualCamera:
                    deviceName = "Dual Camera"
                    nativeZoom = 1.0  // Hauptkamera
                case .builtInTripleCamera:
                    deviceName = "Triple Camera"
                    nativeZoom = 1.0  // Hauptkamera
                case .builtInDualWideCamera:
                    deviceName = "Dual Wide"
                    nativeZoom = 1.0
                default:
                    deviceName = "Unknown"
                    nativeZoom = 1.0
                }

                self.availableCameras[nativeZoom] = device
                print("✅ \(deviceName) gefunden (native Zoom: \(String(format: "%.1fx", nativeZoom)))")
            }

            // Sortiere Zoom-Faktoren für UI
            self.cameraZoomFactors = Array(self.availableCameras.keys).sorted()
            print("📷 Verfügbare Kamera-Zoom-Faktoren: \(self.cameraZoomFactors.map { String(format: "%.1fx", $0) }.joined(separator: ", "))")

            // Configure camera input (Standard: Wide Angle)
            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                do {
                    let input = try AVCaptureDeviceInput(device: camera)
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                        self.videoDeviceInput = input
                        self.currentCamera = camera

                        // Update camera position flag
                        DispatchQueue.main.async {
                            self.isFrontCamera = (camera.position == .front)
                        }

                        print("✅ Camera input added (position: \(camera.position == .front ? "front" : "back"))")
                    }
                    
                    // Configure camera settings
                    try camera.lockForConfiguration()

                    // 🔥 CRITICAL: Finde Format das 1080p @ 60 FPS unterstützt
                    var formatFound = false
                    var selectedFormat: AVCaptureDevice.Format?

                    for format in camera.formats {
                        let description = format.formatDescription
                        let dimensions = CMVideoFormatDescriptionGetDimensions(description)

                        // Suche 1920x1080 Format
                        if dimensions.width == 1920 && dimensions.height == 1080 {
                            // Prüfe ob dieses Format 60 FPS unterstützt
                            for range in format.videoSupportedFrameRateRanges {
                                if range.maxFrameRate >= 60.0 {
                                    selectedFormat = format
                                    formatFound = true
                                    print("✅ Found 1080p 60 FPS format: \(dimensions.width)x\(dimensions.height) @ \(range.maxFrameRate) FPS")
                                    break
                                }
                            }
                            if formatFound { break }
                        }
                    }

                    // Setze das gefundene Format
                    if let format = selectedFormat {
                        camera.activeFormat = format
                        print("✅ Set active format to 1080p 60 FPS")
                    } else {
                        print("⚠️ No 1080p 60 FPS format found, using default format")
                        // Fallback: Versuche 720p 60 FPS
                        for format in camera.formats {
                            let description = format.formatDescription
                            let dimensions = CMVideoFormatDescriptionGetDimensions(description)

                            if dimensions.width == 1280 && dimensions.height == 720 {
                                for range in format.videoSupportedFrameRateRanges {
                                    if range.maxFrameRate >= 60.0 {
                                        camera.activeFormat = format
                                        print("✅ Fallback: Set to 720p 60 FPS")
                                        formatFound = true
                                        break
                                    }
                                }
                                if formatFound { break }
                            }
                        }
                    }

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

                    // Frame rate configuration - Setze jetzt 60 FPS auf dem gewählten Format
                    // ML-Modell läuft mit 1-5ms inference (200+ FPS capable)
                    if let activeFormat = camera.activeFormat.videoSupportedFrameRateRanges.first {
                        let maxFrameRate = activeFormat.maxFrameRate

                        if maxFrameRate >= 60.0 {
                            // Setze 60 FPS
                            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
                            camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
                            print("✅ Frame rate set to 60 FPS (ML model handles 200+ FPS)")
                        } else {
                            // Fallback auf Maximum
                            let targetFPS = Int32(maxFrameRate)
                            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: targetFPS)
                            camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: targetFPS)
                            print("⚠️ Frame rate set to \(targetFPS) FPS (device maximum)")
                        }
                    }
                    
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

        // Torch ausschalten vor dem Stoppen
        if let device = currentCamera, device.hasTorch && device.torchMode != .off {
            do {
                try device.lockForConfiguration()
                device.torchMode = .off
                device.unlockForConfiguration()
                print("🔦 Taschenlampe beim Session-Stop ausgeschaltet")
            } catch {
                print("⚠️ Fehler beim Ausschalten der Taschenlampe: \(error)")
            }
        }

        DispatchQueue.main.async {
            self.isCameraReady = false
            self.isTorchOn = false
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
        // 📷 ADAPTIVE KAMERA-SWITCHING
        // Prüfe ob es eine native Kamera für diesen Zoom-Faktor gibt
        if let targetCamera = availableCameras[factor] {
            // Wechsle zur nativen Kamera für diesen Zoom-Faktor
            switchToCamera(targetCamera, nativeZoom: factor)
            return
        }

        // Kein natives Kamera-Device → Nutze digitalen Zoom auf aktueller Kamera
        applyZoomToCurrentCamera(factor)
    }

    private func applyZoomToCurrentCamera(_ factor: CGFloat) {
        guard let device = currentCamera else { return }

        do {
            try device.lockForConfiguration()

            let clampedFactor = max(device.minAvailableVideoZoomFactor,
                                   min(factor, device.maxAvailableVideoZoomFactor))

            device.videoZoomFactor = clampedFactor
            currentZoomFactor = factor
            device.unlockForConfiguration()

            print("📷 Zoom gesetzt: \(String(format: "%.1fx", clampedFactor))")
        } catch {
            print("❌ Error setting zoom: \(error)")
        }
    }

    /// Wechselt zur angegebenen Kamera (adaptiv für alle Kameratypen)
    private func switchToCamera(_ targetCamera: AVCaptureDevice, nativeZoom: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            // Prüfe ob wir schon auf dieser Kamera sind
            if self.currentCamera == targetCamera {
                print("📷 Bereits auf gewünschter Kamera (\(String(format: "%.1fx", nativeZoom)))")
                DispatchQueue.main.async {
                    self.currentZoomFactor = nativeZoom
                }
                return
            }

            self.session.beginConfiguration()

            // Entferne aktuellen Input
            if let input = self.videoDeviceInput {
                self.session.removeInput(input)
            }

            do {
                // 🔥 KRITISCH: Konfiguriere Kamera VOR dem Hinzufügen zur Session!
                // Dies verhindert den -17281 Fehler
                try targetCamera.lockForConfiguration()

                    // Suche 1080p 60 FPS Format für diese Kamera
                    var formatFound = false
                    var selectedFormat: AVCaptureDevice.Format?

                    for format in targetCamera.formats {
                        let description = format.formatDescription
                        let dimensions = CMVideoFormatDescriptionGetDimensions(description)

                        // Suche 1920x1080 Format
                        if dimensions.width == 1920 && dimensions.height == 1080 {
                            // Prüfe ob dieses Format 60 FPS unterstützt
                            for range in format.videoSupportedFrameRateRanges {
                                if range.maxFrameRate >= 60.0 {
                                    selectedFormat = format
                                    formatFound = true
                                    print("✅ Found 1080p 60 FPS format for new camera: \(dimensions.width)x\(dimensions.height) @ \(range.maxFrameRate) FPS")
                                    break
                                }
                            }
                            if formatFound { break }
                        }
                    }

                    // Setze das gefundene Format oder Fallback zu 720p
                    if let format = selectedFormat {
                        targetCamera.activeFormat = format
                    } else {
                        print("⚠️ No 1080p 60 FPS format found for new camera, trying 720p...")
                        // Fallback: Versuche 720p 60 FPS
                        for format in targetCamera.formats {
                            let description = format.formatDescription
                            let dimensions = CMVideoFormatDescriptionGetDimensions(description)

                            if dimensions.width == 1280 && dimensions.height == 720 {
                                for range in format.videoSupportedFrameRateRanges {
                                    if range.maxFrameRate >= 60.0 {
                                        targetCamera.activeFormat = format
                                        print("✅ Fallback: Set to 720p 60 FPS")
                                        formatFound = true
                                        break
                                    }
                                }
                                if formatFound { break }
                            }
                        }
                    }

                    // Setze Frame Rate auf 60 FPS
                    if let activeFormat = targetCamera.activeFormat.videoSupportedFrameRateRanges.first {
                        let maxFrameRate = activeFormat.maxFrameRate

                        if maxFrameRate >= 60.0 {
                            targetCamera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
                            targetCamera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
                            print("✅ Frame rate set to 60 FPS on new camera")
                        } else {
                            let targetFPS = Int32(maxFrameRate)
                            targetCamera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: targetFPS)
                            targetCamera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: targetFPS)
                            print("⚠️ Frame rate set to \(targetFPS) FPS (device maximum)")
                        }
                    }

                    // Auto-focus konfigurieren
                    if targetCamera.isFocusModeSupported(.continuousAutoFocus) {
                        targetCamera.focusMode = .continuousAutoFocus
                    }

                    // Auto-exposure konfigurieren
                    if targetCamera.isExposureModeSupported(.continuousAutoExposure) {
                        targetCamera.exposureMode = .continuousAutoExposure
                    }

                targetCamera.unlockForConfiguration()

                // JETZT ist die Kamera konfiguriert → füge sie zur Session hinzu
                let newInput = try AVCaptureDeviceInput(device: targetCamera)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.videoDeviceInput = newInput
                    self.currentCamera = targetCamera

                    // Video Connection neu konfigurieren
                    if let connection = self.videoDataOutput.connection(with: .video) {
                        connection.isEnabled = true

                        if #available(iOS 17.0, *) {
                            if connection.isVideoRotationAngleSupported(90) {
                                connection.videoRotationAngle = 90
                            }
                        } else {
                            if connection.isVideoOrientationSupported {
                                connection.videoOrientation = .portrait
                            }
                        }

                        connection.isEnabled = true
                    }

                    // Kamera-Typ Name für Logging
                    let cameraName: String
                    switch targetCamera.deviceType {
                    case .builtInUltraWideCamera: cameraName = "Ultra Wide"
                    case .builtInWideAngleCamera: cameraName = "Wide Angle"
                    case .builtInTelephotoCamera: cameraName = "Telephoto"
                    case .builtInDualCamera: cameraName = "Dual Camera"
                    case .builtInTripleCamera: cameraName = "Triple Camera"
                    case .builtInDualWideCamera: cameraName = "Dual Wide"
                    default: cameraName = "Unknown"
                    }

                    DispatchQueue.main.async {
                        self.currentZoomFactor = nativeZoom
                        print("📷 ✅ Gewechselt zu \(cameraName) (\(String(format: "%.1fx", nativeZoom))) - Format optimiert")
                    }
                }
            } catch {
                print("❌ Error switching camera: \(error)")
            }

            self.session.commitConfiguration()
        }
    }
    
    private func updateAvailableZoomFactors() {
        // 📷 ADAPTIVE ZOOM-FAKTOREN basierend auf erkannten Kameras
        var factors: [CGFloat] = []

        // Füge alle nativen Kamera-Zoom-Faktoren hinzu (aus Discovery Session)
        factors.append(contentsOf: cameraZoomFactors)

        // Optional: Füge zusätzliche digitale Zoom-Faktoren hinzu (z.B. 3x wenn Gerät es unterstützt)
        if let device = currentCamera {
            // Füge 3x hinzu wenn möglich (digital zoom auf aktueller Kamera)
            if device.maxAvailableVideoZoomFactor >= 3.0 && !factors.contains(3.0) {
                factors.append(3.0)
            }
        }

        // Sortiere Faktoren aufsteigend
        factors.sort()

        DispatchQueue.main.async {
            self.availableZoomFactors = factors
            print("📷 Verfügbare Zoom-Faktoren (adaptiv): \(factors.map { String(format: "%.1fx", $0) }.joined(separator: ", "))")
        }
    }
    
    func startLiveAnalysis() {
        isAnalyzing = true
        frameCount = 0
        isActivelyTracking = false
        isDetectingPose = false  // Bereit für Arm-Erkennung
        armRaisedStartTime = nil
        framesWithoutHammer = 0  // Reset timeout counter
        hammerTracker?.resetTracking()
        poseAnalyzer.reset()

        DispatchQueue.main.async {
            self.poseDetectionStatus = "Arm zur Seite strecken"
        }

        print("🎬 Live Analyse gestartet")
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
        let t0 = Date()
        print("⏱️ [0.000s] completeAnalysis() STARTED")

        // Stop tracking und Analysis komplett
        isActivelyTracking = false
        isAnalyzing = false  // ⚠️ WICHTIG: Stoppe Analyse während TTS!
        isDetectingPose = false  // Bereit für nächsten Zyklus
        armRaisedStartTime = nil

        var resultsText = ""

        // Nur Trajektorien-Analyse (Ellipsen-Winkel)
        let t1 = Date()
        print("⏱️ [\(String(format: "%.3f", t1.timeIntervalSince(t0)))s] Calling analyzeTrajectory()...")

        if let analysis = hammerTracker?.analyzeTrajectory() {
            let t2 = Date()
            print("⏱️ [\(String(format: "%.3f", t2.timeIntervalSince(t0)))s] analyzeTrajectory() completed, formatting results...")
            resultsText = formatAnalysisResults(analysis)
            let t3 = Date()
            print("⏱️ [\(String(format: "%.3f", t3.timeIntervalSince(t0)))s] formatAnalysisResults() completed")
        } else {
            resultsText = "Keine vollständige Trajektorie erkannt."
        }

        let t4 = Date()
        print("⏱️ [\(String(format: "%.3f", t4.timeIntervalSince(t0)))s] Dispatching to main thread...")

        DispatchQueue.main.async {
            let t5 = Date()
            print("⏱️ [\(String(format: "%.3f", t5.timeIntervalSince(t0)))s] Main thread async block STARTED")

            self.poseDetectionStatus = "Sage Ergebnisse vor..."
            self.isSpeaking = true

            // Nur TTS-Ausgabe (keine Bildschirm-Anzeige)
            let t6 = Date()
            print("⏱️ [\(String(format: "%.3f", t6.timeIntervalSince(t0)))s] Calling speakResults()...")
            self.speakResults(resultsText, startTime: t0)

            // Nach TTS wird über Delegate automatisch wieder bereit gemacht
        }
    }
    
    private func formatAnalysisResults(_ analysis: TrajectoryAnalysis) -> String {
        var results = ""

        for (index, ellipse) in analysis.ellipses.enumerated() {
            let direction = ellipse.angle > 0 ? "rechts" : "links"
            let absAngle = abs(ellipse.angle)
            results += "Drehung \(index + 1) \(String(format: "%.0f", absAngle)) grad nach \(direction). "

            // 🎯 Füge Oberkörper-Winkel am Umkehrpunkt 1 (2. Punkt) hinzu
            if let torsoAngle = ellipse.torsoAngleAtSecondPoint {
                let torsoDirection: String
                let absTorsoAngle = abs(torsoAngle)

                if torsoAngle > 5 {
                    torsoDirection = "nach vorne"
                } else if torsoAngle < -5 {
                    torsoDirection = "nach hinten"
                } else {
                    torsoDirection = "aufrecht"  // Zwischen -5° und +5° = aufrecht
                }

                if absTorsoAngle > 5 {
                    results += "Oberkörper \(String(format: "%.0f", absTorsoAngle)) grad \(torsoDirection). "
                } else {
                    results += "Oberkörper \(torsoDirection). "
                }
            }
        }

        return results.trimmingCharacters(in: .whitespaces)
    }
    
    private func speakResults(_ text: String, startTime: Date) {
        let t7 = Date()
        print("⏱️ [\(String(format: "%.3f", t7.timeIntervalSince(startTime)))s] speakResults() STARTED")

        // Stop any ongoing speech
        if speechSynthesizer.isSpeaking {
            print("⏱️ [\(String(format: "%.3f", t7.timeIntervalSince(startTime)))s] Stopping ongoing speech...")
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let t8 = Date()
        print("⏱️ [\(String(format: "%.3f", t8.timeIntervalSince(startTime)))s] Creating utterance...")

        let utterance = AVSpeechUtterance(string: text)

        // 🎙️ Normale Geschwindigkeit (0.5 = Standard)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        // 🎙️ Nutze gecachte Stimme (INSTANT, keine Suche!)
        utterance.voice = cachedVoice

        let t9 = Date()
        print("⏱️ [\(String(format: "%.3f", t9.timeIntervalSince(startTime)))s] Calling speechSynthesizer.speak()...")
        print("🔊 Starting TTS (rate: normal): \(text)")

        speechSynthesizer.speak(utterance)

        let t10 = Date()
        print("⏱️ [\(String(format: "%.3f", t10.timeIntervalSince(startTime)))s] speechSynthesizer.speak() RETURNED (TTS now in background)")
    }
    
    func toggleFlash() {
        guard let device = currentCamera else { return }

        // Prüfe ob Taschenlampe verfügbar ist
        guard device.hasTorch && device.isTorchAvailable else {
            print("⚠️ Taschenlampe nicht verfügbar auf dieser Kamera")
            return
        }

        do {
            try device.lockForConfiguration()

            if device.torchMode == .off {
                // Taschenlampe einschalten
                if device.isTorchModeSupported(.on) {
                    try device.setTorchModeOn(level: 1.0)  // Volle Helligkeit
                    DispatchQueue.main.async {
                        self.isTorchOn = true
                        print("🔦 Taschenlampe EIN")
                    }
                }
            } else {
                // Taschenlampe ausschalten
                device.torchMode = .off
                DispatchQueue.main.async {
                    self.isTorchOn = false
                    print("🔦 Taschenlampe AUS")
                }
            }

            device.unlockForConfiguration()
        } catch {
            print("❌ Fehler beim Umschalten der Taschenlampe: \(error)")
        }
    }
    
    func switchCamera() {
        // Torch ausschalten vor dem Kamerawechsel (Frontkamera hat kein Torch)
        if let device = currentCamera, device.hasTorch && device.torchMode != .off {
            do {
                try device.lockForConfiguration()
                device.torchMode = .off
                device.unlockForConfiguration()
                print("🔦 Taschenlampe beim Kamerawechsel ausgeschaltet")
            } catch {
                print("⚠️ Fehler beim Ausschalten der Taschenlampe: \(error)")
            }
        }
        DispatchQueue.main.async {
            self.isTorchOn = false
        }

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
            // 🔥 KRITISCH: Kamera VOR dem Hinzufügen konfigurieren (verhindert -17281)
            try newCamera.lockForConfiguration()

            // Format suchen: 1080p 60 FPS
            var formatFound = false
            for format in newCamera.formats {
                let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                if dimensions.width == 1920 && dimensions.height == 1080 {
                    for range in format.videoSupportedFrameRateRanges {
                        if range.maxFrameRate >= 60.0 {
                            newCamera.activeFormat = format
                            formatFound = true
                            break
                        }
                    }
                    if formatFound { break }
                }
            }
            // Fallback: 720p 60 FPS
            if !formatFound {
                for format in newCamera.formats {
                    let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    if dimensions.width == 1280 && dimensions.height == 720 {
                        for range in format.videoSupportedFrameRateRanges {
                            if range.maxFrameRate >= 60.0 {
                                newCamera.activeFormat = format
                                formatFound = true
                                break
                            }
                        }
                        if formatFound { break }
                    }
                }
            }

            // FPS setzen
            if let activeRange = newCamera.activeFormat.videoSupportedFrameRateRanges.first {
                if activeRange.maxFrameRate >= 60.0 {
                    newCamera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
                    newCamera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
                }
            }

            // Auto-focus / Auto-exposure
            if newCamera.isFocusModeSupported(.continuousAutoFocus) {
                newCamera.focusMode = .continuousAutoFocus
            }
            if newCamera.isExposureModeSupported(.continuousAutoExposure) {
                newCamera.exposureMode = .continuousAutoExposure
            }

            newCamera.unlockForConfiguration()

            // JETZT zur Session hinzufügen
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoDeviceInput = newInput
                currentCamera = newCamera

                // Update camera position flag
                DispatchQueue.main.async {
                    self.isFrontCamera = (newCamera.position == .front)
                    print("📷 Camera switched to: \(newCamera.position == .front ? "FRONT" : "BACK")")
                }

                // Video Connection für neue Kamera neu konfigurieren
                if let connection = videoDataOutput.connection(with: .video) {
                    connection.isEnabled = true

                    if #available(iOS 17.0, *) {
                        if connection.isVideoRotationAngleSupported(90) {
                            connection.videoRotationAngle = 90
                        }
                    } else {
                        if connection.isVideoOrientationSupported {
                            connection.videoOrientation = .portrait
                        }
                    }

                    connection.isEnabled = true
                }
            }
        } catch {
            print("❌ Error switching camera: \(error)")
        }

        session.commitConfiguration()
        updateAvailableZoomFactors()
    }

    func togglePoseDetection() {
        isPoseDetectionEnabled.toggle()

        // Clear pose visualization wenn disabled
        if !isPoseDetectionEnabled {
            DispatchQueue.main.async {
                self.detectedPose = nil
            }
        }

        print("Pose detection \(isPoseDetectionEnabled ? "enabled" : "disabled")")
    }
}

// Extension for AVSpeechSynthesizerDelegate
extension CameraManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 TTS ACTUALLY STARTED SPEAKING!")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("✅ TTS finished, ready for next analysis")

        DispatchQueue.main.async {
            self.isSpeaking = false

            // ⚡ WICHTIG: Analyse automatisch neu starten nach TTS!
            self.startLiveAnalysis()

            print("🔄 Analyse automatisch neu gestartet - bereit für nächsten Zyklus")
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("⚠️ TTS cancelled")

        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isDetectingPose = false
            self.poseDetectionStatus = "Arm zur Seite strecken"
        }
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

        // Pose Detection (IMMER wenn enabled, auch ohne Analyse für Live-Preview!)
        // 🔥 CRITICAL FIX: Throttle während Tracking um Freeze zu vermeiden
        if isPoseDetectionEnabled && poseRequest != nil {
            poseFrameCounter += 1

            // Während Tracking: Nur jeden 3. Frame (20 FPS), sonst jeden Frame (60 FPS)
            let shouldProcessPose = !isActivelyTracking || (poseFrameCounter >= poseProcessingInterval)

            if shouldProcessPose {
                if isActivelyTracking {
                    poseFrameCounter = 0  // Reset counter nur während Tracking
                }

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
        }

        // Hammer Detection - IMMER AKTIV (für Live Bounding Box, genau wie Pose Detection)
        if let hammerModel = hammerDetectionModel {
            visionProcessingQueue.async { [weak self] in
                guard let self = self else { return }

                let request = VNCoreMLRequest(model: hammerModel) { [weak self] request, error in
                    guard let self = self else { return }

                    if let error = error {
                        print("Hammer detection error: \(error)")
                        return
                    }

                    guard let results = request.results as? [VNRecognizedObjectObservation],
                          let bestDetection = results.max(by: { $0.confidence < $1.confidence }),
                          bestDetection.confidence >= 0.3 else {
                        // Kein Hammer erkannt - Box entfernen und Timeout-Counter erhöhen
                        DispatchQueue.main.async {
                            self.detectedHammerBox = nil

                            // ⏱️ Timeout: Zähle Frames ohne Hammer während Tracking
                            if self.isActivelyTracking {
                                self.framesWithoutHammer += 1

                                // Nach 60 Frames (1 Sekunde) ohne Hammer → Analyse beenden
                                if self.framesWithoutHammer >= self.maxFramesWithoutHammer {
                                    print("⏱️ Timeout: 60 Frames (1 Sekunde) ohne Hammer → Analyse wird beendet")
                                    self.completeAnalysis()
                                }
                            }
                        }
                        return
                    }

                    // Hammer erkannt - Box publishen und Timeout-Counter zurücksetzen
                    DispatchQueue.main.async {
                        self.detectedHammerBox = bestDetection.boundingBox

                        // ⏱️ Reset Timeout-Counter wenn Hammer erkannt
                        if self.isActivelyTracking {
                            self.framesWithoutHammer = 0
                        }
                    }
                }

                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    print("Failed to perform hammer detection: \(error)")
                }
            }
        }

        // Hammer Tracking für Analyse (nur wenn aktiv)
        if isAnalyzing {
            let currentFrameCount = frameCount
            let currentTorso = currentTorsoAngle  // Capture torso angle für Frame

            hammerTrackingQueue.async { [weak self] in
                guard let self = self else { return }

                // Process frame for tracking with torso angle
                self.hammerTracker?.processLiveFrame(pixelBuffer, frameNumber: currentFrameCount, torsoAngle: currentTorso)
            }
        }
    }
}

// Rest of the UI components remain the same...
struct CameraPreviewFixed: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: ((CGPoint, CGPoint) -> Void)?  // (screenPoint, devicePoint)

    func makeUIView(context: Context) -> UIView {
        print("🎥 Creating camera preview view...")
        let view = CameraPreviewView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        // Ensure connection is properly configured
        if let connection = previewLayer.connection {
            connection.isEnabled = true
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
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
        // Session status is tracked elsewhere - no need for per-frame logging
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }
    
    class Coordinator: NSObject {
        let onTap: ((CGPoint, CGPoint) -> Void)?  // (screenPoint, devicePoint)
        weak var previewLayer: AVCaptureVideoPreviewLayer?

        init(onTap: ((CGPoint, CGPoint) -> Void)?) {
            self.onTap = onTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)

            if let previewLayer = previewLayer {
                let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: location)
                onTap?(location, devicePoint)
            } else {
                onTap?(location, location)
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

struct PoseSkeletonView: View {
    let observation: VNHumanBodyPoseObservation
    let isFrontCamera: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw skeleton connections (lines)
                ForEach(PoseConnection.allConnections, id: \.id) { connection in
                    if let startPoint = try? observation.recognizedPoint(connection.start),
                       let endPoint = try? observation.recognizedPoint(connection.end),
                       startPoint.confidence > 0.1 && endPoint.confidence > 0.1 {

                        let start = convertVisionPoint(startPoint.location, in: geometry.size, isFrontCamera: isFrontCamera)
                        let end = convertVisionPoint(endPoint.location, in: geometry.size, isFrontCamera: isFrontCamera)

                        Path { path in
                            path.move(to: start)
                            path.addLine(to: end)
                        }
                        .stroke(Color.green, lineWidth: 3)
                    }
                }

                // Draw joints (circles)
                ForEach(PoseJoint.allJoints) { joint in
                    if let point = try? observation.recognizedPoint(joint.name),
                       point.confidence > 0.1 {

                        let position = convertVisionPoint(point.location, in: geometry.size, isFrontCamera: isFrontCamera)

                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .position(position)
                    }
                }
            }
        }
    }

    private func convertVisionPoint(_ point: CGPoint, in size: CGSize, isFrontCamera: Bool) -> CGPoint {
        // Vision gibt Koordinaten für LANDSCAPE zurück (wegen orientation: .right)
        // Aber wir zeichnen auf PORTRAIT Display

        // Landscape → Portrait Transformation (90° CW Rotation):
        if isFrontCamera {
            // Frontkamera: X-Achse spiegeln für Selfie-Effekt
            return CGPoint(
                x: point.y * size.width,         // Landscape Y → Portrait X (gespiegelt)
                y: (1 - point.x) * size.height   // Landscape X → Portrait Y
            )
        } else {
            // Rückkamera: Normal
            return CGPoint(
                x: (1 - point.y) * size.width,   // Landscape Y → Portrait X
                y: (1 - point.x) * size.height   // Landscape X → Portrait Y
            )
        }
    }
}

// Hammer Bounding Box View - Live Anzeige der Hammer-Detektion
struct HammerBoundingBoxView: View {
    let boundingBox: CGRect
    let isFrontCamera: Bool

    var body: some View {
        GeometryReader { geometry in
            let rect = convertVisionRect(boundingBox, in: geometry.size, isFrontCamera: isFrontCamera)

            Rectangle()
                .stroke(Color.red, lineWidth: 3)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .overlay(
                    // Label "HAMMER" oben links
                    Text("HAMMER")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .position(x: rect.minX + 35, y: rect.minY - 10)
                )
        }
    }

    private func convertVisionRect(_ rect: CGRect, in size: CGSize, isFrontCamera: Bool) -> CGRect {
        // Vision gibt Koordinaten für LANDSCAPE zurück (wegen orientation: .right)
        // Aber wir zeichnen auf PORTRAIT Display
        // Deshalb müssen wir die Achsen tauschen: X→Y, Y→X

        // Landscape → Portrait Transformation (90° CW Rotation):
        if isFrontCamera {
            // Frontkamera: X-Achse spiegeln für Selfie-Effekt
            let portraitX = rect.minY * size.width              // Landscape Y → Portrait X (gespiegelt)
            let portraitY = (1 - rect.maxX) * size.height       // Landscape X → Portrait Y
            let portraitWidth = rect.height * size.width        // Landscape height → Portrait width
            let portraitHeight = rect.width * size.height       // Landscape width → Portrait height

            return CGRect(x: portraitX, y: portraitY, width: portraitWidth, height: portraitHeight)
        } else {
            // Rückkamera: Normal
            let portraitX = (1 - rect.maxY) * size.width       // Landscape Y → Portrait X
            let portraitY = (1 - rect.maxX) * size.height      // Landscape X → Portrait Y
            let portraitWidth = rect.height * size.width       // Landscape height → Portrait width
            let portraitHeight = rect.width * size.height      // Landscape width → Portrait height

            return CGRect(x: portraitX, y: portraitY, width: portraitWidth, height: portraitHeight)
        }
    }
}

// Helper struct to make joints identifiable for ForEach
struct PoseJoint: Identifiable {
    let id = UUID()
    let name: VNHumanBodyPoseObservation.JointName

    static let allJoints = [
        PoseJoint(name: .nose),
        PoseJoint(name: .neck),
        PoseJoint(name: .rightShoulder),
        PoseJoint(name: .rightElbow),
        PoseJoint(name: .rightWrist),
        PoseJoint(name: .leftShoulder),
        PoseJoint(name: .leftElbow),
        PoseJoint(name: .leftWrist),
        PoseJoint(name: .rightHip),
        PoseJoint(name: .rightKnee),
        PoseJoint(name: .rightAnkle),
        PoseJoint(name: .leftHip),
        PoseJoint(name: .leftKnee),
        PoseJoint(name: .leftAnkle),
        PoseJoint(name: .root),
        PoseJoint(name: .rightEye),
        PoseJoint(name: .leftEye),
        PoseJoint(name: .rightEar),
        PoseJoint(name: .leftEar)
    ]
}

struct PoseConnection: Identifiable {
    let id = UUID()
    let start: VNHumanBodyPoseObservation.JointName
    let end: VNHumanBodyPoseObservation.JointName

    static let allConnections: [PoseConnection] = [
        // Torso
        PoseConnection(start: .neck, end: .root),

        // Left arm
        PoseConnection(start: .neck, end: .leftShoulder),
        PoseConnection(start: .leftShoulder, end: .leftElbow),
        PoseConnection(start: .leftElbow, end: .leftWrist),

        // Right arm
        PoseConnection(start: .neck, end: .rightShoulder),
        PoseConnection(start: .rightShoulder, end: .rightElbow),
        PoseConnection(start: .rightElbow, end: .rightWrist),

        // Left leg
        PoseConnection(start: .root, end: .leftHip),
        PoseConnection(start: .leftHip, end: .leftKnee),
        PoseConnection(start: .leftKnee, end: .leftAnkle),

        // Right leg
        PoseConnection(start: .root, end: .rightHip),
        PoseConnection(start: .rightHip, end: .rightKnee),
        PoseConnection(start: .rightKnee, end: .rightAnkle),
    ]
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

// 🧪 Torso Angle Display View
struct TorsoAngleView: View {
    let angle: Double

    var body: some View {
        VStack(spacing: 4) {
            Text("Oberkörper-Neigung")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            HStack(spacing: 6) {
                // Icon basierend auf Richtung
                Image(systemName: angle > 0 ? "arrow.forward" : "arrow.backward")
                    .font(.system(size: 14))
                    .foregroundColor(angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)

                // Winkel-Wert
                Text(String(format: "%.1f°", abs(angle)))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                // Richtung
                Text(angle > 0 ? "VORNE" : "HINTEN")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: (angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary).opacity(0.3), radius: 10, x: 0, y: 4)
        )
    }
}

// Camera Controls View - Kompakte einzeilige Version
struct CameraControlsView: View {
    @ObservedObject var cameraManager: CameraManager

    var body: some View {
        HStack(spacing: 12) {
            // Zoom Controls links
            zoomControls

            Spacer()

            // Pose Detection + Flash + Camera Switch rechts
            poseDetectionButton
            flashButton
            switchButton
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .liquidGlassEffect(style: .thin, cornerRadius: 16)
    }

    // Zoom Controls
    private var zoomControls: some View {
        HStack(spacing: 8) {
            ForEach(cameraManager.availableZoomFactors, id: \.self) { factor in
                zoomButton(for: factor)
            }
        }
    }

    private func zoomButton(for factor: CGFloat) -> some View {
        let isSelected = cameraManager.currentZoomFactor == factor

        return Button(action: {
            cameraManager.setZoomFactor(factor)
        }) {
            Text(formatZoomFactor(factor))
                .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .black : .white)
                .frame(minWidth: 44)
                .frame(height: 38)
                .background(isSelected ? Color.white : Color.white.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private var poseDetectionButton: some View {
        let isPoseOn = cameraManager.isPoseDetectionEnabled
        let iconName = isPoseOn ? "figure.walk" : "figure.walk.slash"
        let bgColor = isPoseOn ? LiquidGlassColors.primary : Color.white.opacity(0.1)

        return Button(action: {
            cameraManager.togglePoseDetection()
        }) {
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(bgColor))
                .overlay(Circle().stroke(LiquidGlassColors.glassBorder, lineWidth: 1.5))
        }
    }

    private var flashButton: some View {
        let isTorchOn = cameraManager.isTorchOn
        let iconName = isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill"
        let bgColor = isTorchOn ? LiquidGlassColors.primary : Color.white.opacity(0.1)

        return Button(action: {
            cameraManager.toggleFlash()
        }) {
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(bgColor))
                .overlay(Circle().stroke(LiquidGlassColors.glassBorder, lineWidth: 1.5))
        }
    }

    private var switchButton: some View {
        Button(action: {
            cameraManager.switchCamera()
        }) {
            Image(systemName: "camera.rotate")
                .font(.system(size: 18))
                .foregroundColor(.white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.white.opacity(0.1)))
                .overlay(Circle().stroke(LiquidGlassColors.glassBorder, lineWidth: 1.5))
        }
    }

    private func formatZoomFactor(_ factor: CGFloat) -> String {
        if factor < 1.0 {
            return String(format: "%.1fx", factor)
        } else if factor.truncatingRemainder(dividingBy: 1.0) == 0 {
            return String(format: "%.0fx", factor)
        } else {
            return String(format: "%.1fx", factor)
        }
    }
}
