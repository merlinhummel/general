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
        containerView.addSubview(scrollView)
        
        // Video container view (what we zoom)
        let videoContainerView = UIView()
        scrollView.addSubview(videoContainerView)
        
        // Setup video layer
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        videoContainerView.layer.addSublayer(playerLayer)
        
        // Setup trajectory layer
        let trajectoryLayer = CAShapeLayer()
        trajectoryLayer.strokeColor = UIColor.white.cgColor
        trajectoryLayer.fillColor = UIColor.clear.cgColor
        trajectoryLayer.lineWidth = 3.0
        trajectoryLayer.lineCap = .round
        trajectoryLayer.lineJoin = .round
        videoContainerView.layer.addSublayer(trajectoryLayer)
        
        // Current position indicator
        let currentPositionLayer = CAShapeLayer()
        currentPositionLayer.fillColor = UIColor.yellow.cgColor
        currentPositionLayer.strokeColor = UIColor.orange.cgColor
        currentPositionLayer.lineWidth = 2.0
        videoContainerView.layer.addSublayer(currentPositionLayer)
        
        // Store references
        context.coordinator.scrollView = scrollView
        context.coordinator.videoContainerView = videoContainerView
        context.coordinator.playerLayer = playerLayer
        context.coordinator.trajectoryLayer = trajectoryLayer
        context.coordinator.currentPositionLayer = currentPositionLayer
        
        // Add pinch gesture for zooming
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        scrollView.addGestureRecognizer(pinchGesture)
        
        // Add double tap gesture for quick zoom
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.showTrajectory = showTrajectory
        context.coordinator.updateTrajectory(trajectory, currentTime: currentTime, showFullTrajectory: showFullTrajectory)
        
        // Only update layout if bounds have changed
        if context.coordinator.lastBounds != uiView.bounds {
            context.coordinator.lastBounds = uiView.bounds
            DispatchQueue.main.async {
                context.coordinator.updateLayout(in: uiView.bounds)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var videoContainerView: UIView?
        weak var playerLayer: AVPlayerLayer?
        weak var trajectoryLayer: CAShapeLayer?
        weak var currentPositionLayer: CAShapeLayer?
        var showTrajectory = true
        var lastBounds: CGRect = .zero
        
        func updateLayout(in bounds: CGRect) {
            guard let scrollView = scrollView,
                  let videoContainerView = videoContainerView,
                  let playerLayer = playerLayer else { return }
            
            // Save current zoom scale and content offset
            let currentZoomScale = scrollView.zoomScale
            let wasZoomed = currentZoomScale > scrollView.minimumZoomScale
            let contentOffset = scrollView.contentOffset
            
            // Update scroll view frame
            scrollView.frame = bounds
            
            // Update video container to match scroll view size initially
            if !wasZoomed {
                videoContainerView.frame = CGRect(origin: .zero, size: bounds.size)
            }
            
            // Update player layer
            playerLayer.frame = videoContainerView.bounds
            
            // Update scroll view content size
            scrollView.contentSize = videoContainerView.frame.size
            
            // Update trajectory layer frame
            trajectoryLayer?.frame = videoContainerView.bounds
            currentPositionLayer?.frame = videoContainerView.bounds
            
            // Restore zoom and offset if needed
            if wasZoomed {
                scrollView.zoomScale = currentZoomScale
                scrollView.contentOffset = contentOffset
            }
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            
            if gesture.state == .began || gesture.state == .changed {
                let currentScale = scrollView.zoomScale
                let newScale = currentScale * gesture.scale
                let boundedScale = min(max(newScale, scrollView.minimumZoomScale), scrollView.maximumZoomScale)
                scrollView.zoomScale = boundedScale
                gesture.scale = 1.0
            }
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let location = gesture.location(in: scrollView)
                let rect = CGRect(x: location.x - 50, y: location.y - 50, width: 100, height: 100)
                scrollView.zoom(to: rect, animated: true)
            }
        }
        
        // UIScrollViewDelegate
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return videoContainerView
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let videoContainerView = videoContainerView else { return }
            
            // Center the video view when it's smaller than scroll view
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            videoContainerView.center = CGPoint(
                x: scrollView.contentSize.width * 0.5 + offsetX,
                y: scrollView.contentSize.height * 0.5 + offsetY
            )
            
            // Update trajectory line width based on zoom
            let scale = scrollView.zoomScale
            trajectoryLayer?.lineWidth = 3.0 / scale
            currentPositionLayer?.lineWidth = 2.0 / scale
        }
        
        func updateTrajectory(_ trajectory: Trajectory?, currentTime: Double, showFullTrajectory: Bool) {
            guard let trajectory = trajectory,
                  let trajectoryLayer = trajectoryLayer,
                  let currentPositionLayer = currentPositionLayer,
                  let videoContainerView = videoContainerView,
                  showTrajectory else {
                trajectoryLayer?.path = nil
                currentPositionLayer?.path = nil
                return
            }
            
            let bounds = videoContainerView.bounds
            guard bounds.width > 0 && bounds.height > 0 else { return }
            
            // Get the actual video frame within the container (considering aspect ratio)
            guard let playerLayer = playerLayer else { return }
            let videoRect = playerLayer.videoRect
            
            // Create trajectory path using smoothed points
            let path = UIBezierPath()
            var hasStarted = false
            
            // Use smoothed points from trajectory
            let smoothedPoints = trajectory.smoothedPoints
            
            for (index, point) in smoothedPoints.enumerated() {
                // Convert normalized coordinates (0-1) to video frame coordinates
                let displayPoint = CGPoint(
                    x: videoRect.origin.x + (point.x * videoRect.width),
                    y: videoRect.origin.y + (point.y * videoRect.height)
                )
                
                if showFullTrajectory {
                    if !hasStarted {
                        path.move(to: displayPoint)
                        hasStarted = true
                    } else {
                        path.addLine(to: displayPoint)
                    }
                } else {
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
            if let currentFrame = trajectory.frames.first(where: { abs($0.timestamp - currentTime) < 0.05 }) {
                let currentPoint = CGPoint(
                    x: videoRect.origin.x + (currentFrame.boundingBox.midX * videoRect.width),
                    y: videoRect.origin.y + (currentFrame.boundingBox.midY * videoRect.height)
                )
                
                let scale = scrollView?.zoomScale ?? 1.0
                let radius = 8.0 / scale
                let circlePath = UIBezierPath(arcCenter: currentPoint, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                currentPositionLayer.path = circlePath.cgPath
            } else {
                currentPositionLayer.path = nil
            }
        }
    }
}
