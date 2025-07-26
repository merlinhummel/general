import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

struct CompareView: View {
    @State private var showingVideoPicker = false
    @State private var selectedVideoURLs: [URL] = []
    @State private var player1: AVPlayer?
    @State private var player2: AVPlayer?
    @State private var isPlaying = false
    @State private var isSynchronized = false
    @State private var currentTime1: Double = 0
    @State private var currentTime2: Double = 0
    @State private var duration1: Double = 0
    @State private var duration2: Double = 0
    
    @StateObject private var hammerTracker1 = HammerTracker()
    @StateObject private var hammerTracker2 = HammerTracker()
    @State private var showTrajectory = true
    @State private var videoSize1: CGSize = .zero
    @State private var videoSize2: CGSize = .zero
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button (always visible)
            HStack {
                Button(action: {
                    if player1 != nil || player2 != nil {
                        // Reset players and go back to selection
                        player1 = nil
                        player2 = nil
                        selectedVideoURLs = []
                    } else {
                        // Go back to main menu
                        presentationMode.wrappedValue.dismiss()
                    }
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
                
                Text("Compare View")
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
            
            if selectedVideoURLs.count == 2 {
                // Video Player 1 (Top Half)
                VStack(spacing: 0) {
                    if let player = player1 {
                        ZStack {
                            ZoomableVideoView(
                                player: player,
                                trajectory: showTrajectory ? hammerTracker1.currentTrajectory : nil,
                                currentTime: $currentTime1,
                                showFullTrajectory: false,
                                showTrajectory: showTrajectory
                            )
                            .background(Color.black)
                            .overlay(
                                Text("Video 1")
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(4)
                                    .padding(8),
                                alignment: .topLeading
                            )
                            
                            // Processing overlay
                            if hammerTracker1.isProcessing {
                                VStack(spacing: 8) {
                                    ProgressView()
                                    Text("Processing: \(Int(hammerTracker1.progress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(12)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Compact Controls for Player 1
                    CompactVideoControls(
                        player: player1,
                        currentTime: $currentTime1,
                        duration: $duration1,
                        playerNumber: 1,
                        isSynchronized: isSynchronized,
                        syncTime: $currentTime2,
                        syncPlayer: player2
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: .infinity)
                
                Divider()
                
                // Video Player 2 (Bottom Half)
                VStack(spacing: 0) {
                    if let player = player2 {
                        ZStack {
                            ZoomableVideoView(
                                player: player,
                                trajectory: showTrajectory ? hammerTracker2.currentTrajectory : nil,
                                currentTime: $currentTime2,
                                showFullTrajectory: false,
                                showTrajectory: showTrajectory
                            )
                            .background(Color.black)
                            .overlay(
                                Text("Video 2")
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(4)
                                    .padding(8),
                                alignment: .topLeading
                            )
                            
                            // Processing overlay
                            if hammerTracker2.isProcessing {
                                VStack(spacing: 8) {
                                    ProgressView()
                                    Text("Processing: \(Int(hammerTracker2.progress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(12)
                                .background(Color.black.opacity(0.8))
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Compact Controls for Player 2
                    CompactVideoControls(
                        player: player2,
                        currentTime: $currentTime2,
                        duration: $duration2,
                        playerNumber: 2,
                        isSynchronized: isSynchronized,
                        syncTime: $currentTime1,
                        syncPlayer: player1
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: .infinity)
                
                // Master Controls (Compact)
                MasterControlsView(
                    player1: player1,
                    player2: player2,
                    isPlaying: $isPlaying,
                    isSynchronized: $isSynchronized,
                    currentTime1: $currentTime1,
                    currentTime2: $currentTime2,
                    duration1: duration1,
                    duration2: duration2,
                    showTrajectory: $showTrajectory
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Wählen Sie zwei Videos zum Vergleichen")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        showingVideoPicker = true
                    }) {
                        Text("Videos auswählen")
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
            MultipleVideoPicker(selectedVideoURLs: $selectedVideoURLs)
        }
        .onChange(of: selectedVideoURLs) { _, urls in
            if urls.count == 2 {
                setupPlayers(with: urls)
                processVideos(urls: urls)
            }
        }
    }
    
    private func setupPlayers(with urls: [URL]) {
        guard urls.count == 2 else { return }
        
        player1 = AVPlayer(url: urls[0])
        player2 = AVPlayer(url: urls[1])
        
        // Load durations and sizes
        Task {
            let asset1 = AVURLAsset(url: urls[0])
            let asset2 = AVURLAsset(url: urls[1])
            
            do {
                let duration1 = try await asset1.load(.duration)
                self.duration1 = duration1.seconds
                
                let duration2 = try await asset2.load(.duration)
                self.duration2 = duration2.seconds
                
                if let track1 = asset1.tracks(withMediaType: .video).first {
                    let size = try await track1.load(.naturalSize)
                    let transform = try await track1.load(.preferredTransform)
                    self.videoSize1 = size.applying(transform)
                }
                
                if let track2 = asset2.tracks(withMediaType: .video).first {
                    let size = try await track2.load(.naturalSize)
                    let transform = try await track2.load(.preferredTransform)
                    self.videoSize2 = size.applying(transform)
                }
            } catch {
                print("Error loading durations: \(error)")
            }
        }
        
        // Add time observers with millisecond precision
        addTimeObservers()
    }
    
    private func addTimeObservers() {
        let interval = CMTime(seconds: 0.001, preferredTimescale: 1000)
        
        player1?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime1 = time.seconds
        }
        
        player2?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime2 = time.seconds
        }
    }
    
    private func processVideos(urls: [URL]) {
        guard urls.count == 2 else { return }
        
        // Process video 1
        hammerTracker1.processVideo(url: urls[0]) { result in
            switch result {
            case .success(let trajectory):
                print("Video 1 processing complete. Detected \(trajectory.frames.count) frames")
                _ = hammerTracker1.analyzeTrajectory()
            case .failure(let error):
                print("Error processing video 1: \(error)")
            }
        }
        
        // Process video 2
        hammerTracker2.processVideo(url: urls[1]) { result in
            switch result {
            case .success(let trajectory):
                print("Video 2 processing complete. Detected \(trajectory.frames.count) frames")
                _ = hammerTracker2.analyzeTrajectory()
            case .failure(let error):
                print("Error processing video 2: \(error)")
            }
        }
    }
}

struct MultipleVideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURLs: [URL]
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 2
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultipleVideoPicker
        
        init(_ parent: MultipleVideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            var urls: [URL] = []
            let group = DispatchGroup()
            
            for result in results {
                let provider = result.itemProvider
                
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    group.enter()
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                        if let url = url {
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                            try? FileManager.default.copyItem(at: url, to: tempURL)
                            urls.append(tempURL)
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.parent.selectedVideoURLs = urls
            }
        }
    }
}

struct CompactVideoControls: View {
    let player: AVPlayer?
    @Binding var currentTime: Double
    @Binding var duration: Double
    let playerNumber: Int
    let isSynchronized: Bool
    @Binding var syncTime: Double
    let syncPlayer: AVPlayer?
    
    @State private var isDraggingSlider = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Time label
            Text(formatTime(currentTime))
                .font(.system(.caption2, design: .monospaced))
                .frame(width: 60)
            
            // Timeline
            Slider(
                value: Binding(
                    get: { currentTime },
                    set: { newValue in
                        currentTime = newValue
                        if isDraggingSlider, let player = player {
                            let cmTime = CMTime(seconds: newValue, preferredTimescale: 1000)
                            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
                            
                            // Sync the other player if synchronized - move to same time
                            if isSynchronized, let syncPlayer = syncPlayer {
                                syncPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
                                syncTime = newValue
                            }
                        }
                    }
                ),
                in: 0...max(duration, 1)
            ) { editing in
                isDraggingSlider = editing
                if !editing, let player = player {
                    let cmTime = CMTime(seconds: currentTime, preferredTimescale: 1000)
                    player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
                    
                    // Final sync if needed
                    if isSynchronized, let syncPlayer = syncPlayer {
                        syncPlayer.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
                        syncTime = currentTime
                    }
                }
            }
            .accentColor(.blue)
            
            Text(formatTime(duration))
                .font(.system(.caption2, design: .monospaced))
                .frame(width: 60)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, secs, milliseconds)
    }
}

struct MasterControlsView: View {
    let player1: AVPlayer?
    let player2: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var isSynchronized: Bool
    @Binding var currentTime1: Double
    @Binding var currentTime2: Double
    let duration1: Double
    let duration2: Double
    @Binding var showTrajectory: Bool
    
    @State private var frameStepTimer: Timer?
    @State private var frameStepCount = 0
    
    var body: some View {
        HStack(spacing: 15) {
            // Sync button
            Button(action: {
                isSynchronized.toggle()
                if isSynchronized {
                    synchronizePlayers()
                }
            }) {
                VStack(spacing: 2) {
                    Image(systemName: isSynchronized ? "link" : "link.badge.plus")
                        .font(.title3)
                    Text("Sync")
                        .font(.caption2)
                }
                .foregroundColor(isSynchronized ? .blue : .gray)
            }
            
            Spacer()
            
            // Playback controls
            HStack(spacing: 15) {
                // Frame backward
                Button(action: {
                    stepFrameBoth(forward: false)
                }) {
                    Image(systemName: "backward.frame")
                        .font(.title2)
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
                        .font(.title)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                
                // Frame forward
                Button(action: {
                    stepFrameBoth(forward: true)
                }) {
                    Image(systemName: "forward.frame")
                        .font(.title2)
                }
                .onLongPressGesture(minimumDuration: 0.2, maximumDistance: .infinity, pressing: { pressing in
                    if pressing {
                        startFrameStepping(forward: true)
                    } else {
                        stopFrameStepping()
                    }
                }, perform: {})
            }
            
            Spacer()
            
            // Trajectory toggle
            Button(action: {
                showTrajectory.toggle()
            }) {
                VStack(spacing: 2) {
                    Image(systemName: showTrajectory ? "eye" : "eye.slash")
                        .font(.title3)
                    Text("Traj.")
                        .font(.caption2)
                }
                .foregroundColor(showTrajectory ? .blue : .gray)
            }
        }
    }
    
    private func togglePlayPause() {
        if isPlaying {
            player1?.pause()
            player2?.pause()
        } else {
            player1?.play()
            player2?.play()
        }
        isPlaying.toggle()
    }
    
    private func stepFrameBoth(forward: Bool) {
        if isSynchronized {
            // When synchronized, step both players together
            let frameRate: Double = 30
            let frameDuration = 1.0 / frameRate
            
            let newTime1 = forward ? currentTime1 + frameDuration : currentTime1 - frameDuration
            let clampedTime1 = max(0, min(newTime1, duration1))
            
            player1?.seek(to: CMTime(seconds: clampedTime1, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
            player2?.seek(to: CMTime(seconds: clampedTime1, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
            
            currentTime1 = clampedTime1
            currentTime2 = clampedTime1
        } else {
            // When not synchronized, step individually
            stepFrame(player: player1, forward: forward, currentTime: currentTime1, duration: duration1)
            stepFrame(player: player2, forward: forward, currentTime: currentTime2, duration: duration2)
        }
    }
    
    private func stepFrame(player: AVPlayer?, forward: Bool, currentTime: Double, duration: Double) {
        guard let player = player else { return }
        
        let frameRate: Double = 30
        let frameDuration = 1.0 / frameRate
        let newTime = forward ? currentTime + frameDuration : currentTime - frameDuration
        let clampedTime = max(0, min(newTime, duration))
        
        player.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func startFrameStepping(forward: Bool) {
        frameStepCount = 0
        
        // 7 frames per second when holding
        frameStepTimer = Timer.scheduledTimer(withTimeInterval: 1.0/7.0, repeats: true) { _ in
            stepFrameBoth(forward: forward)
        }
    }
    
    private func stopFrameStepping() {
        frameStepTimer?.invalidate()
        frameStepTimer = nil
        frameStepCount = 0
    }
    
    private func synchronizePlayers() {
        guard let player1 = player1, let player2 = player2 else { return }
        
        let currentTime = player1.currentTime()
        player2.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime2 = currentTime1
    }
}
