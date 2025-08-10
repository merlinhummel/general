import SwiftUI
import AVFoundation

// Minimaler Kamera-Test für LiveView
struct CameraTestView: View {
    @StateObject private var camera = MinimalCameraManager()
    
    var body: some View {
        ZStack {
            // Kamera Preview
            CameraTestPreview(session: camera.session)
                .ignoresSafeArea()
            
            // Status Overlay
            VStack {
                // Status Indikator
                HStack {
                    Circle()
                        .fill(camera.isRunning ? Color.green : Color.red)
                        .frame(width: 20, height: 20)
                    
                    Text(camera.isRunning ? "Kamera läuft" : "Kamera startet...")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .padding()
                
                Spacer()
                
                // Debug Info
                VStack(alignment: .leading, spacing: 5) {
                    Text("Status: \(camera.statusMessage)")
                    Text("Frames: \(camera.frameCount)")
                    Text("Inputs: \(camera.inputCount)")
                    Text("Outputs: \(camera.outputCount)")
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
                .padding()
            }
        }
        .onAppear {
            camera.startCamera()
        }
        .onDisappear {
            camera.stopCamera()
        }
    }
}

// Minimaler Kamera Manager
class MinimalCameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isRunning = false
    @Published var statusMessage = "Initialisierung..."
    @Published var frameCount = 0
    @Published var inputCount = 0
    @Published var outputCount = 0
    
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private var videoOutput: AVCaptureVideoDataOutput?
    
    override init() {
        super.init()
    }
    
    func startCamera() {
        checkPermissionAndSetup()
    }
    
    func stopCamera() {
        sessionQueue.async {
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
                self.statusMessage = "Kamera gestoppt"
            }
        }
    }
    
    private func checkPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupCamera()
                } else {
                    DispatchQueue.main.async {
                        self?.statusMessage = "Kamera-Zugriff verweigert"
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.statusMessage = "Kamera-Zugriff verweigert"
            }
        @unknown default:
            break
        }
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.statusMessage = "Kamera wird eingerichtet..."
            }
            
            // Session konfigurieren
            self.session.beginConfiguration()
            
            // Alte Inputs/Outputs entfernen
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }
            
            // Session Preset
            self.session.sessionPreset = .high
            
            // Kamera finden
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.statusMessage = "Keine Kamera gefunden"
                }
                return
            }
            
            // Input hinzufügen
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                    
                    // Output hinzufügen
                    let output = AVCaptureVideoDataOutput()
                    output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "video.output"))
                    
                    if self.session.canAddOutput(output) {
                        self.session.addOutput(output)
                        self.videoOutput = output
                    }
                }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.statusMessage = "Fehler: \(error.localizedDescription)"
                }
                return
            }
            
            // Configuration abschließen
            self.session.commitConfiguration()
            
            // Session starten NACH commitConfiguration - auf separatem Thread
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
                
                DispatchQueue.main.async {
                    self.isRunning = self.session.isRunning
                    self.statusMessage = self.isRunning ? "Kamera läuft" : "Start fehlgeschlagen"
                    self.inputCount = self.session.inputs.count
                    self.outputCount = self.session.outputs.count
                }
            }
        }
    }
}

// Video Delegate
extension MinimalCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            self.frameCount += 1
        }
    }
}

// Preview
struct CameraTestPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Speichere Layer für Updates
        view.layer.setValue(previewLayer, forKey: "previewLayer")
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.value(forKey: "previewLayer") as? AVCaptureVideoPreviewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
}