import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

struct SingleView: View {
    @State private var showingVideoPicker = false
    @State private var selectedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?
    
    @StateObject private var hammerTracker = HammerTracker()
    @State private var showTrajectory = true
    @State private var videoSize: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                if player != nil {
                    Button(action: {
                        // Reset player and go back
                        player = nil
                        selectedVideoURL = nil
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Zurück")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.blue)
                    }
                } else {
                    Color.clear
                        .frame(width: 60, height: 20)
                }
                
                Spacer()
                
                Text("Single View")
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
            
            if let player = player {
                ZStack {
                    ZoomableVideoView(
                        player: player,
                        trajectory: showTrajectory ? hammerTracker.currentTrajectory : nil,
                        currentTime: $currentTime,
                        showFullTrajectory: false,
                        showTrajectory: showTrajectory
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .clipped()
                    
                    // Processing overlay
                    if hammerTracker.isProcessing {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Analysiere Video...")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ProgressView(value: hammerTracker.progress)
                                .frame(width: 200)
                                .tint(.white)
                            
                            Text("\(Int(hammerTracker.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(15)
                    }
                    
                    // Small trajectory toggle in bottom right of video
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { showTrajectory.toggle() }) {
                                Image(systemName: showTrajectory ? "eye" : "eye.slash")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                        }
                    }
                }
                
                VideoControlsView(
                    player: player,
                    isPlaying: $isPlaying,
                    currentTime: $currentTime,
                    duration: $duration
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Wählen Sie ein Video aus")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        showingVideoPicker = true
                    }) {
                        Text("Video auswählen")
                            .foregroundColor(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 15)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray6))
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingVideoPicker) {
            VideoPicker(selectedVideoURL: $selectedVideoURL)
        }
        .onChange(of: selectedVideoURL) { _, newURL in
            if let url = newURL {
                setupPlayer(with: url)
                processVideo(url: url)
            }
        }
        .onDisappear {
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
            }
        }
    }
    
    private func setupPlayer(with url: URL) {
        player = AVPlayer(url: url)
        
        // Get video duration and size
        let asset = AVURLAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                self.duration = duration.seconds
                
                if let track = asset.tracks(withMediaType: .video).first {
                    let size = try await track.load(.naturalSize)
                    let transform = try await track.load(.preferredTransform)
                    let transformedSize = size.applying(transform)
                    // Use absolute values to ensure positive dimensions
                    self.videoSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
                }
            } catch {
                print("Error loading duration: \(error)")
            }
        }
        
        // Add time observer
        if let player = player {
            let interval = CMTime(seconds: 0.01, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                currentTime = time.seconds
            }
        }
    }
    
    private func processVideo(url: URL) {
        hammerTracker.processVideo(url: url) { result in
            switch result {
            case .success(let trajectory):
                print("Video processing complete. Detected \(trajectory.frames.count) frames")
                if let analysis = hammerTracker.analyzeTrajectory() {
                    print("Analysis complete: \(analysis.ellipses.count) ellipses found")
                }
            case .failure(let error):
                print("Error processing video: \(error)")
            }
        }
    }
}

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    if let url = url {
                        // Copy to temporary location
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        try? FileManager.default.copyItem(at: url, to: tempURL)
                        
                        DispatchQueue.main.async {
                            self.parent.selectedVideoURL = tempURL
                        }
                    }
                }
            }
        }
    }
}

struct VideoControlsView: View {
    let player: AVPlayer
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    
    @State private var isDraggingSlider = false
    @State private var frameStepTimer: Timer?
    @State private var frameStepCount = 0
    
    var body: some View {
        VStack(spacing: 8) {
            // Timeline
            Slider(
                value: Binding(
                    get: { currentTime },
                    set: { newValue in
                        currentTime = newValue
                        if isDraggingSlider {
                            seek(to: newValue)
                        }
                    }
                ),
                in: 0...max(duration, 1)
            ) { editing in
                isDraggingSlider = editing
                if !editing {
                    seek(to: currentTime)
                }
            }
            .accentColor(.blue)
            .frame(height: 20)
            
            // Time labels
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formatTime(duration))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            // Control buttons
            HStack(spacing: 25) {
                // Frame backward
                Button(action: {
                    stepFrame(forward: false)
                }) {
                    Image(systemName: "backward.frame")
                        .font(.title3)
                }
                .onLongPressGesture(minimumDuration: 0.2, maximumDistance: .infinity, pressing: { pressing in
                    if pressing {
                        startFrameStepping(forward: false)
                    } else {
                        stopFrameStepping()
                    }
                }, perform: {})
                
                // Play/Pause
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                
                // Frame forward
                Button(action: {
                    stepFrame(forward: true)
                }) {
                    Image(systemName: "forward.frame")
                        .font(.title3)
                }
                .onLongPressGesture(minimumDuration: 0.2, maximumDistance: .infinity, pressing: { pressing in
                    if pressing {
                        startFrameStepping(forward: true)
                    } else {
                        stopFrameStepping()
                    }
                }, perform: {})
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onChange(of: isPlaying) { _, playing in
            if playing {
                // Update play/pause state based on player
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: player.currentItem,
                    queue: .main
                ) { _ in
                    isPlaying = false
                    seek(to: 0)
                }
            }
        }
    }
    
    private func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func stepFrame(forward: Bool) {
        let frameRate: Double = 30 // Assuming 30 fps
        let frameDuration = 1.0 / frameRate
        let currentCMTime = player.currentTime()
        let currentSeconds = currentCMTime.seconds
        
        let newTime = forward ? currentSeconds + frameDuration : currentSeconds - frameDuration
        let clampedTime = max(0, min(newTime, duration))
        
        seek(to: clampedTime)
    }
    
    private func startFrameStepping(forward: Bool) {
        frameStepCount = 0
        
        // 7 frames per second when holding
        frameStepTimer = Timer.scheduledTimer(withTimeInterval: 1.0/7.0, repeats: true) { _ in
            stepFrame(forward: forward)
        }
    }
    
    private func stopFrameStepping() {
        frameStepTimer?.invalidate()
        frameStepTimer = nil
        frameStepCount = 0
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        let milliseconds = Int((seconds - Double(totalSeconds)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, secs, milliseconds)
    }
}
