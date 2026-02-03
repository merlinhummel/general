import SwiftUI
import AVKit
import UIKit

// MARK: - Zoomable Video View
struct ZoomableVideoView: UIViewRepresentable {
    let player: AVPlayer
    let trajectory: Trajectory?
    @Binding var currentTime: Double
    let showFullTrajectory: Bool
    let showTrajectory: Bool
    let selectedEllipseIndex: Int?  // Wenn gesetzt, nur diese Ellipse anzeigen
    let analysisResult: TrajectoryAnalysis?  // Für Ellipsen-Info
    var onEllipseTapped: ((Int?) -> Void)?  // Callback wenn Ellipse getippt wird (nil = Modus beenden)
    
    func makeUIView(context: Context) -> UIView {
        print("🎬 ZoomableVideoView makeUIView called")
        print("   Player: \(player)")
        print("   Player.currentItem: \(player.currentItem)")

        let containerView = UIView()
        containerView.backgroundColor = .black

        // Create scroll view for zooming
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 10.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isScrollEnabled = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        containerView.addSubview(scrollView)

        // Video container view (what we zoom)
        let videoContainerView = UIView()
        scrollView.addSubview(videoContainerView)
        // Setup video layer - videoGravity wird in updateLayout() basierend auf Video-Format gesetzt
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill // Default, wird in updateLayout() angepasst
        videoContainerView.layer.addSublayer(playerLayer)

        print("✅ PlayerLayer created with frame: \(playerLayer.frame)")
        
        // Setup trajectory layer with improved styling
        let trajectoryLayer = CAShapeLayer()
        trajectoryLayer.strokeColor = UIColor.white.cgColor
        trajectoryLayer.fillColor = UIColor.clear.cgColor
        trajectoryLayer.lineWidth = 1.5  // Reduced from 3.0
        trajectoryLayer.lineCap = .round
        trajectoryLayer.lineJoin = .round
        
        // Add shadow for better visibility
        trajectoryLayer.shadowColor = UIColor.black.cgColor
        trajectoryLayer.shadowOpacity = 0.5
        trajectoryLayer.shadowOffset = CGSize(width: 0, height: 0)
        trajectoryLayer.shadowRadius = 2.0
        videoContainerView.layer.addSublayer(trajectoryLayer)
        
        // Current position indicator with improved styling
        let currentPositionLayer = CAShapeLayer()
        currentPositionLayer.fillColor = UIColor.yellow.cgColor
        currentPositionLayer.strokeColor = UIColor.orange.cgColor
        currentPositionLayer.lineWidth = 1.0  // Reduced from 2.0

        // Add shadow for better visibility
        currentPositionLayer.shadowColor = UIColor.black.cgColor
        currentPositionLayer.shadowOpacity = 0.5
        currentPositionLayer.shadowOffset = CGSize(width: 0, height: 0)
        currentPositionLayer.shadowRadius = 2.0
        videoContainerView.layer.addSublayer(currentPositionLayer)

        
        // Store references
        context.coordinator.containerView = containerView
        context.coordinator.scrollView = scrollView
        context.coordinator.videoContainerView = videoContainerView
        context.coordinator.playerLayer = playerLayer
        context.coordinator.trajectoryLayer = trajectoryLayer
        context.coordinator.currentPositionLayer = currentPositionLayer
        context.coordinator.onEllipseTapped = onEllipseTapped

        // Add single tap gesture for ellipse selection
        let singleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingleTap(_:)))
        singleTapGesture.numberOfTapsRequired = 1
        videoContainerView.addGestureRecognizer(singleTapGesture)

        // Add double tap gesture for reset zoom
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)

        // Single tap should wait for double tap to fail
        singleTapGesture.require(toFail: doubleTapGesture)

        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // WICHTIG: Update player wenn er sich ändert
        if let playerLayer = context.coordinator.playerLayer {
            if playerLayer.player !== player {
                print("🔄 Updating player in playerLayer")
                playerLayer.player = player

                // Reset zoom state when player changes (handles same-video reanalysis)
                print("🔄 Resetting zoom state for new video")
                context.coordinator.currentZoomScale = 1.0
                context.coordinator.currentContentOffset = .zero
                context.coordinator.scrollView?.setZoomScale(1.0, animated: false)
                context.coordinator.scrollView?.setContentOffset(.zero, animated: false)

                // ⚡ WICHTIG: Force layout update bei Player-Wechsel
                // Reset lastBounds damit Layout neu berechnet wird
                context.coordinator.lastBounds = .zero
                print("🔄 Forcing layout update for new player")

                // Beobachte wenn Video bereit ist für korrektes Layout
                context.coordinator.observePlayerItemStatus()
            }
        }

        if showTrajectory {
            context.coordinator.updateTrajectory(
                trajectory,
                currentTime: currentTime,
                showFullTrajectory: showFullTrajectory,
                selectedEllipseIndex: selectedEllipseIndex,
                analysisResult: analysisResult
            )
        } else {
            context.coordinator.trajectoryLayer?.path = nil
            context.coordinator.currentPositionLayer?.isHidden = true
        }

        // Only update layout if bounds have changed (not on every frame)
        context.coordinator.updateLayoutIfNeeded()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }    
    // MARK: - Coordinator
    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var containerView: UIView?
        weak var scrollView: UIScrollView?
        weak var videoContainerView: UIView?
        weak var playerLayer: AVPlayerLayer?
        weak var trajectoryLayer: CAShapeLayer?
        weak var currentPositionLayer: CAShapeLayer?

        // Zoom state
        var currentZoomScale: CGFloat = 1.0
        var currentContentOffset: CGPoint = .zero
        var lastBounds: CGRect = .zero
        var isRestoringZoom = false

        // Ellipse tap callback
        var onEllipseTapped: ((Int?) -> Void)?

        // Store current trajectory and analysis for hit-testing
        var currentTrajectory: Trajectory?
        var currentAnalysis: TrajectoryAnalysis?
        var currentVideoRect: CGRect = .zero

        // Status observer
        var statusObserver: NSKeyValueObservation?

        deinit {
            statusObserver?.invalidate()
        }

        func observePlayerItemStatus() {
            // Entferne alten Observer
            statusObserver?.invalidate()

            guard let playerItem = playerLayer?.player?.currentItem else { return }

            // Beobachte Status-Änderungen
            statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
                if item.status == .readyToPlay {
                    print("✅ PlayerItem ready - updating layout for correct video size")
                    DispatchQueue.main.async {
                        // Force layout update mit korrekter Video-Größe
                        self?.lastBounds = .zero
                        self?.updateLayoutIfNeeded()
                    }
                }
            }
        }

        func updateLayoutIfNeeded() {
            guard let containerView = containerView else { return }
            let bounds = containerView.bounds

            // Only update layout if bounds actually changed
            if bounds != lastBounds {
                lastBounds = bounds
                updateLayout()
            }
        }

        func updateLayout() {
            guard let containerView = containerView,
                  let scrollView = scrollView,
                  let videoContainerView = videoContainerView,
                  let playerLayer = playerLayer,
                  let trajectoryLayer = trajectoryLayer,
                  let currentPositionLayer = currentPositionLayer else {
                print("⚠️ updateLayout: Some views are nil!")
                return
            }

            // Verwende containerView bounds - diese sollten durch .ignoresSafeArea() bereits den vollen Bereich umfassen
            let bounds = containerView.bounds

            // Debug: Zeige echten Screen-Bereich vs Container-Bereich
            if let window = containerView.window {
                let screenBounds = UIScreen.main.bounds
                let windowBounds = window.bounds
                let safeAreaInsets = window.safeAreaInsets

                print("📐 Screen & Container Info:")
                print("   Screen bounds: \(screenBounds.width) × \(screenBounds.height)")
                print("   Window bounds: \(windowBounds.width) × \(windowBounds.height)")
                print("   Safe area insets - top: \(safeAreaInsets.top), bottom: \(safeAreaInsets.bottom)")
                print("   Container bounds: \(bounds.width) × \(bounds.height)")
            }

            print("📐 updateLayout called - using bounds: \(bounds)")
            scrollView.frame = bounds

            // Calculate video container size from the actual video track
            var videoSize: CGSize = .zero

            // Versuche die echte Video-Größe aus dem Track zu holen
            if let playerItem = playerLayer.player?.currentItem,
               let asset = playerItem.asset as? AVURLAsset {

                // Synchron die Video-Größe holen (Tracks sind bereits geladen)
                if let track = asset.tracks(withMediaType: .video).first {
                    let naturalSize = track.naturalSize
                    let transform = track.preferredTransform

                    // Wende Transform an für korrekte Rotation
                    let transformedSize = naturalSize.applying(transform)
                    videoSize = CGSize(
                        width: abs(transformedSize.width),
                        height: abs(transformedSize.height)
                    )
                    print("✅ Got video size from track: \(videoSize)")
                }
            }

            // Fallback wenn Track-Größe nicht verfügbar
            if videoSize.width <= 0 || videoSize.height <= 0 {
                // Versuche presentationSize als Backup
                let presentationSize = playerLayer.player?.currentItem?.presentationSize ?? .zero
                if presentationSize.width > 0 && presentationSize.height > 0 {
                    videoSize = CGSize(
                        width: abs(presentationSize.width),
                        height: abs(presentationSize.height)
                    )
                    print("⚠️ Using presentationSize: \(videoSize)")
                } else {
                    // Letzter Fallback: Benutze Container-Größe (AspectFill macht dann keine Cuts)
                    videoSize = bounds.size
                    print("⚠️ Using container bounds as fallback: \(videoSize)")
                }
            }

            // Skalierung basierend auf Video-Format
            let widthScale = bounds.width / videoSize.width
            let heightScale = bounds.height / videoSize.height

            // IMMER ASPECT FILL: Video füllt IMMER den gesamten Container
            let scale = max(widthScale, heightScale)
            let scalingMode = "ASPECT FILL (Always)"
            playerLayer.videoGravity = .resizeAspectFill

            print("📐 Video scaling (\(scalingMode)):")
            print("   Container: \(bounds.width) × \(bounds.height)")
            print("   Video: \(videoSize.width) × \(videoSize.height)")
            print("   widthScale: \(widthScale), heightScale: \(heightScale)")
            print("   finalScale: \(scale)")
            print("   videoGravity: \(playerLayer.videoGravity.rawValue)")

            // minimumZoomScale = 1.0 (Video in Ausgangsposition bei 1.0x)
            scrollView.minimumZoomScale = 1.0

            // maximumZoomScale = 10x zoom
            scrollView.maximumZoomScale = 10.0

            // Video-Container in berechneter Größe
            let scaledSize = CGSize(
                width: videoSize.width * scale,
                height: videoSize.height * scale
            )

            // WICHTIG: videoContainerView startet bei (0, 0) - Zentrierung über contentInset!
            videoContainerView.frame = CGRect(
                x: 0,
                y: 0,
                width: scaledSize.width,
                height: scaledSize.height
            )

            // contentSize = Größe des scrollbaren Inhalts (das Video)
            scrollView.contentSize = scaledSize

            print("   Scaled size: \(scaledSize.width) × \(scaledSize.height)")
            print("   VideoContainer frame: \(videoContainerView.frame)")

            // Update layers
            playerLayer.frame = videoContainerView.bounds
            trajectoryLayer.frame = videoContainerView.bounds
            currentPositionLayer.frame = videoContainerView.bounds

            print("✅ PlayerLayer frame set to: \(playerLayer.frame)")
            print("   VideoContainer bounds: \(videoContainerView.bounds)")
            print("   VideoSize: \(videoSize)")
            print("   ScrollView contentSize: \(scrollView.contentSize)")

            // Center the content if it's smaller than scroll view
            centerContent()

            // WICHTIG: Zoom-Wiederherstellung NICHT mehr hier!
            // Mit UUID-basierter View-Recreation wird die View bei jeder Analyse neu erstellt
            // → Zoom startet automatisch bei 1.0x
        }        
        func centerContent() {
            guard let scrollView = scrollView else { return }

            // WICHTIG: Verwende die tatsächliche GEZOOMTE Größe, nicht nur contentSize!
            let zoomedWidth = scrollView.contentSize.width * scrollView.zoomScale
            let zoomedHeight = scrollView.contentSize.height * scrollView.zoomScale

            // HORIZONTAL: Zentriere Video
            var insetX: CGFloat = 0
            var offsetX: CGFloat = scrollView.contentOffset.x

            if zoomedWidth > scrollView.bounds.width {
                // Video ist BREITER als Container (Hochformat) → Zentriere via contentOffset
                let centerOffset = (zoomedWidth - scrollView.bounds.width) * 0.5
                offsetX = centerOffset
                insetX = 0
            } else {
                // Video ist SCHMALER als Container (Querformat) → Zentriere via contentInset
                insetX = (scrollView.bounds.width - zoomedWidth) * 0.5
                offsetX = 0
            }

            // VERTIKAL: Zentriere Video wenn kleiner als Container
            var insetY: CGFloat = 0
            var offsetY: CGFloat = scrollView.contentOffset.y

            if zoomedHeight > scrollView.bounds.height {
                // Video ist HÖHER als Container → Zentriere via contentOffset
                let centerOffset = (zoomedHeight - scrollView.bounds.height) * 0.5
                offsetY = centerOffset
                insetY = 0
            } else {
                // Video ist NIEDRIGER als Container → Zentriere via contentInset
                insetY = (scrollView.bounds.height - zoomedHeight) * 0.5
                offsetY = 0
            }

            // Nur setzen wenn sich was geändert hat (Performance)
            let newInset = UIEdgeInsets(top: insetY, left: insetX, bottom: insetY, right: insetX)
            if scrollView.contentInset != newInset {
                scrollView.contentInset = newInset
            }

            // Setze contentOffset für Zentrierung bei größerem Content
            let newOffset = CGPoint(x: offsetX, y: offsetY)
            if scrollView.contentOffset != newOffset && scrollView.zoomScale == 1.0 {
                scrollView.contentOffset = newOffset
            }
        }
        
        func updateTrajectory(
            _ trajectory: Trajectory?,
            currentTime: Double,
            showFullTrajectory: Bool,
            selectedEllipseIndex: Int?,
            analysisResult: TrajectoryAnalysis?
        ) {
            guard let trajectory = trajectory,
                  let trajectoryLayer = trajectoryLayer,
                  let currentPositionLayer = currentPositionLayer,
                  let videoContainerView = videoContainerView else {
                trajectoryLayer?.path = nil
                currentPositionLayer?.path = nil
                return
            }

            let bounds = videoContainerView.bounds
            guard bounds.width > 0 && bounds.height > 0 else { return }

            // Get the actual video frame within the container
            guard let playerLayer = playerLayer else { return }
            let videoRect = playerLayer.videoRect

            // If video rect is invalid, use the entire bounds
            let drawRect = (videoRect.width > 0 && videoRect.height > 0 &&
                           !videoRect.width.isNaN && !videoRect.height.isNaN) ? videoRect : bounds

            // Store for hit-testing
            self.currentTrajectory = trajectory
            self.currentAnalysis = analysisResult
            self.currentVideoRect = drawRect

            // Draw trajectory using the same logic as TrajectoryView
            drawTrajectory(
                in: drawRect,
                trajectory: trajectory,
                currentTime: currentTime,
                showFullTrajectory: showFullTrajectory,
                selectedEllipseIndex: selectedEllipseIndex,
                analysisResult: analysisResult
            )
        }        
        private func drawTrajectory(
            in videoRect: CGRect,
            trajectory: Trajectory,
            currentTime: Double,
            showFullTrajectory: Bool,
            selectedEllipseIndex: Int?,
            analysisResult: TrajectoryAnalysis?
        ) {
            guard let trajectoryLayer = trajectoryLayer,
                  let currentPositionLayer = currentPositionLayer else { return }

            // Create trajectory path
            let path = UIBezierPath()
            var hasStarted = false

            // Use lightly smoothed points from trajectory
            let smoothedPoints = trajectory.smoothedPoints

            // Ensure we have valid frames
            guard !smoothedPoints.isEmpty && trajectory.frames.count == smoothedPoints.count else {
                trajectoryLayer.path = nil
                currentPositionLayer.path = nil
                return
            }

            // Wenn eine Ellipse ausgewählt ist, nur deren Punkte zeichnen
            var visibleFrameIndices: Set<Int>?
            if let ellipseIndex = selectedEllipseIndex,
               let analysis = analysisResult,
               ellipseIndex >= 0 && ellipseIndex < analysis.ellipses.count {

                let ellipse = analysis.ellipses[ellipseIndex]

                // Sammle alle frameIndices dieser Ellipse
                var indices = Set<Int>()
                for frame in ellipse.frames {
                    if let index = trajectory.frames.firstIndex(where: { $0.frameNumber == frame.frameNumber }) {
                        indices.insert(index)
                    }
                }
                visibleFrameIndices = indices
            }

            for (index, point) in smoothedPoints.enumerated() {
                // Wenn Ellipsen-Filter aktiv, prüfe ob dieser Punkt zur Ellipse gehört
                if let visible = visibleFrameIndices, !visible.contains(index) {
                    continue
                }

                // Validate point before using
                guard !point.x.isNaN && !point.y.isNaN &&
                      point.x.isFinite && point.y.isFinite else { continue }

                // Transform normalized coordinates (0-1) to display coordinates
                // Flip Y-axis: when object is at top in video, show at top in trajectory
                let displayPoint = CGPoint(
                    x: videoRect.origin.x + (point.x * videoRect.width),
                    y: videoRect.origin.y + ((1.0 - point.y) * videoRect.height)  // Flip Y
                )

                // Validate display point
                guard !displayPoint.x.isNaN && !displayPoint.y.isNaN &&
                      displayPoint.x.isFinite && displayPoint.y.isFinite else { continue }

                // Im Ellipsen-Modus: Zeige IMMER die komplette Ellipse
                if visibleFrameIndices != nil {
                    if !hasStarted {
                        path.move(to: displayPoint)
                        hasStarted = true
                    } else {
                        path.addLine(to: displayPoint)
                    }
                } else if showFullTrajectory {
                    // Normal-Modus: Zeige komplette Trajectory
                    if !hasStarted {
                        path.move(to: displayPoint)
                        hasStarted = true
                    } else {
                        path.addLine(to: displayPoint)
                    }
                } else {
                    // Normal-Modus mit Zeit-Filter: Zeige Trajectory bis currentTime
                    if index < trajectory.frames.count && trajectory.frames[index].timestamp <= currentTime {
                        if !hasStarted {
                            path.move(to: displayPoint)
                            hasStarted = true
                        } else {
                            path.addLine(to: displayPoint)
                        }
                    }
                }
            }

            trajectoryLayer.path = path.cgPath
            
            // Update current position indicator
            let currentFrame = trajectory.frames.enumerated().min { frame1, frame2 in
                abs(frame1.element.timestamp - currentTime) < abs(frame2.element.timestamp - currentTime)
            }
            
            if let (index, frame) = currentFrame, abs(frame.timestamp - currentTime) < 0.1 {
                // Use the smoothed point for the current position
                if index < smoothedPoints.count {
                    let smoothedPoint = smoothedPoints[index]
                    
                    // Validate point
                    guard !smoothedPoint.x.isNaN && !smoothedPoint.y.isNaN &&
                          smoothedPoint.x.isFinite && smoothedPoint.y.isFinite else {
                        currentPositionLayer.isHidden = true
                        return
                    }
                    
                    let currentPoint = CGPoint(
                        x: videoRect.origin.x + (smoothedPoint.x * videoRect.width),
                        y: videoRect.origin.y + ((1.0 - smoothedPoint.y) * videoRect.height)  // Flip Y
                    )
                    
                    // Validate current point
                    guard !currentPoint.x.isNaN && !currentPoint.y.isNaN &&
                          currentPoint.x.isFinite && currentPoint.y.isFinite else {
                        currentPositionLayer.isHidden = true
                        return
                    }
                    
                    let circlePath = UIBezierPath(arcCenter: currentPoint, radius: 8, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                    currentPositionLayer.path = circlePath.cgPath
                    currentPositionLayer.isHidden = false
                } else {
                    currentPositionLayer.isHidden = true
                }
            } else {
                currentPositionLayer.isHidden = true
            }
        }

        // MARK: - UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return videoContainerView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent()
            // Save zoom state continuously
            currentZoomScale = scrollView.zoomScale
            currentContentOffset = scrollView.contentOffset
        }

        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            // Lock zoom when user finishes zooming
            currentZoomScale = scale
            currentContentOffset = scrollView.contentOffset
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Center content while scrolling (for consistent positioning)
            centerContent()

            // Keep content offset updated when zoomed
            if scrollView.zoomScale > 1.0 {
                currentContentOffset = scrollView.contentOffset
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            // Save zoom state when dragging ends
            currentZoomScale = scrollView.zoomScale
            currentContentOffset = scrollView.contentOffset
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            // Save zoom state when scrolling ends
            currentZoomScale = scrollView.zoomScale
            currentContentOffset = scrollView.contentOffset
        }
        
        // MARK: - Gesture Handlers
        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            guard let analysis = currentAnalysis,
                  let trajectory = currentTrajectory,
                  !analysis.ellipses.isEmpty else { return }

            let tapLocation = gesture.location(in: videoContainerView)

            // Finde die Ellipse, die am nächsten zum Tap ist
            if let tappedEllipseIndex = findEllipseAtPoint(tapLocation) {
                // Ellipse wurde getippt → Aktiviere Ellipsen-Modus
                print("🎯 Ellipse \(tappedEllipseIndex) getippt!")
                onEllipseTapped?(tappedEllipseIndex)
            } else {
                // Außerhalb getippt → Deaktiviere Ellipsen-Modus
                print("🔄 Ellipsen-Modus deaktiviert")
                onEllipseTapped?(nil)  // nil bedeutet: zurück zum Normal-Modus
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                // Reset zoom
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                currentZoomScale = 1.0
                currentContentOffset = .zero
            } else {
                // Zoom to 3x on tap location
                let location = gesture.location(in: videoContainerView)
                let zoomScale: CGFloat = 3.0
                let zoomRect = CGRect(
                    x: location.x - (scrollView.bounds.width / (2 * zoomScale)),
                    y: location.y - (scrollView.bounds.height / (2 * zoomScale)),
                    width: scrollView.bounds.width / zoomScale,
                    height: scrollView.bounds.height / zoomScale
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

        // MARK: - Hit Testing
        private func findEllipseAtPoint(_ point: CGPoint) -> Int? {
            guard let analysis = currentAnalysis,
                  let trajectory = currentTrajectory else { return nil }

            let videoRect = currentVideoRect
            let smoothedPoints = trajectory.smoothedPoints

            // Finde die nächstgelegene Ellipse zum Tap
            var closestEllipse: Int? = nil
            var minDistance: CGFloat = 50.0  // Max 50 Punkte Entfernung für Hit

            for (ellipseIndex, ellipse) in analysis.ellipses.enumerated() {
                // Sammle alle Punkte dieser Ellipse
                for frame in ellipse.frames {
                    if let index = trajectory.frames.firstIndex(where: { $0.frameNumber == frame.frameNumber }),
                       index < smoothedPoints.count {

                        let trajPoint = smoothedPoints[index]

                        // Transform to display coordinates
                        let displayPoint = CGPoint(
                            x: videoRect.origin.x + (trajPoint.x * videoRect.width),
                            y: videoRect.origin.y + ((1.0 - trajPoint.y) * videoRect.height)
                        )

                        // Berechne Distanz zum Tap
                        let dx = displayPoint.x - point.x
                        let dy = displayPoint.y - point.y
                        let distance = sqrt(dx * dx + dy * dy)

                        if distance < minDistance {
                            minDistance = distance
                            closestEllipse = ellipseIndex
                        }
                    }
                }
            }

            return closestEllipse
        }
    }
}