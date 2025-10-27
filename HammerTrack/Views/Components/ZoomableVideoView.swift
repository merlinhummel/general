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
    
    func makeUIView(context: Context) -> UIView {
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
        // Setup video layer with aspect fill to fill the container
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill // Changed to fill the container
        videoContainerView.layer.addSublayer(playerLayer)
        
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
        
        // Add double tap gesture for reset zoom
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if showTrajectory {
            context.coordinator.updateTrajectory(trajectory, currentTime: currentTime, showFullTrajectory: showFullTrajectory)
        } else {
            context.coordinator.trajectoryLayer?.path = nil
            context.coordinator.currentPositionLayer?.isHidden = true
        }
        
        DispatchQueue.main.async {
            context.coordinator.updateLayout()
        }
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
        
        func updateLayout() {
            guard let containerView = containerView,
                  let scrollView = scrollView,
                  let videoContainerView = videoContainerView,
                  let playerLayer = playerLayer,
                  let trajectoryLayer = trajectoryLayer,
                  let currentPositionLayer = currentPositionLayer else { return }
            
            let bounds = containerView.bounds
            scrollView.frame = bounds
            
            // Calculate video container size to fit the video
            var videoSize = playerLayer.player?.currentItem?.presentationSize ?? CGSize(width: 1920, height: 1080)
            // Ensure positive dimensions
            videoSize.width = abs(videoSize.width)
            videoSize.height = abs(videoSize.height)
            
            guard videoSize.width > 0 && videoSize.height > 0 else {
                // Fallback if video size is invalid
                videoSize = CGSize(width: 1920, height: 1080)
                return
            }
            
            // For aspect fill, we need to calculate the scaling differently
            let containerAspect = bounds.width / bounds.height
            let videoAspect = videoSize.width / videoSize.height
            
            var scale: CGFloat = 1.0
            if containerAspect > videoAspect {
                // Container is wider than video - scale based on width
                scale = bounds.width / videoSize.width
            } else {
                // Container is taller than video - scale based on height
                scale = bounds.height / videoSize.height
            }
            
            let scaledSize = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
            let videoRect = CGRect(
                x: (bounds.width - scaledSize.width) / 2,
                y: (bounds.height - scaledSize.height) / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )
            
            videoContainerView.frame = videoRect
            scrollView.contentSize = videoRect.size
            
            // Update layers
            playerLayer.frame = videoContainerView.bounds
            trajectoryLayer.frame = videoContainerView.bounds
            currentPositionLayer.frame = videoContainerView.bounds
            
            // Center the content if it's smaller than scroll view
            centerContent()
            
            // Restore zoom state if we had one
            if currentZoomScale > 1.0 {
                scrollView.setZoomScale(currentZoomScale, animated: false)
                scrollView.setContentOffset(currentContentOffset, animated: false)
            }
        }        
        func centerContent() {
            guard let scrollView = scrollView else { return }
            
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
        }
        
        func updateTrajectory(_ trajectory: Trajectory?, currentTime: Double, showFullTrajectory: Bool) {
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
            
            // Draw trajectory using the same logic as TrajectoryView
            drawTrajectory(in: drawRect, trajectory: trajectory, currentTime: currentTime, showFullTrajectory: showFullTrajectory)
        }        
        private func drawTrajectory(in videoRect: CGRect, trajectory: Trajectory, currentTime: Double, showFullTrajectory: Bool) {
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
            
            for (index, point) in smoothedPoints.enumerated() {
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
                
                if showFullTrajectory {
                    if !hasStarted {
                        path.move(to: displayPoint)
                        hasStarted = true
                    } else {
                        path.addLine(to: displayPoint)
                    }
                }                else {
                    // Show trajectory up to current time
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
            // Save zoom state
            currentZoomScale = scrollView.zoomScale
            currentContentOffset = scrollView.contentOffset
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            // Save zoom state when dragging ends
            currentContentOffset = scrollView.contentOffset
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            // Save zoom state when scrolling ends
            currentContentOffset = scrollView.contentOffset
        }
        
        // MARK: - Gesture Handlers
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let location = gesture.location(in: videoContainerView)
                let rect = CGRect(x: location.x - 50, y: location.y - 50, width: 100, height: 100)
                scrollView.zoom(to: rect, animated: true)
            }
        }
    }
}