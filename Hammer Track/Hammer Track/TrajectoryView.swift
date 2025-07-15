import SwiftUI
import AVKit
import UIKit
import AVFoundation

struct TrajectoryVideoContainer: UIViewRepresentable {
    let player: AVPlayer
    let trajectory: Trajectory?
    @Binding var currentTime: Double
    let showFullTrajectory: Bool
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        
        // Setup video layer
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        containerView.layer.addSublayer(playerLayer)
        
        // Setup trajectory layer for white trajectory overlay
        let trajectoryLayer = CAShapeLayer()
        trajectoryLayer.strokeColor = UIColor.white.cgColor
        trajectoryLayer.fillColor = UIColor.clear.cgColor
        trajectoryLayer.lineWidth = 3.0
        trajectoryLayer.lineCap = .round
        trajectoryLayer.lineJoin = .round
        containerView.layer.addSublayer(trajectoryLayer)
        
        // Setup current position indicator
        let currentPositionLayer = CAShapeLayer()
        currentPositionLayer.fillColor = UIColor.yellow.cgColor
        currentPositionLayer.strokeColor = UIColor.orange.cgColor
        currentPositionLayer.lineWidth = 2.0
        containerView.layer.addSublayer(currentPositionLayer)
        
        context.coordinator.containerView = containerView
        context.coordinator.playerLayer = playerLayer
        context.coordinator.trajectoryLayer = trajectoryLayer
        context.coordinator.currentPositionLayer = currentPositionLayer
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.updateTrajectory(trajectory, currentTime: currentTime, showFullTrajectory: showFullTrajectory)
        
        DispatchQueue.main.async {
            context.coordinator.updateLayout()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        weak var containerView: UIView?
        weak var playerLayer: AVPlayerLayer?
        weak var trajectoryLayer: CAShapeLayer?
        weak var currentPositionLayer: CAShapeLayer?
        
        func updateLayout() {
            guard let containerView = containerView,
                  let playerLayer = playerLayer,
                  let trajectoryLayer = trajectoryLayer,
                  let currentPositionLayer = currentPositionLayer else { return }
            
            let bounds = containerView.bounds
            playerLayer.frame = bounds
            trajectoryLayer.frame = bounds
            currentPositionLayer.frame = bounds
        }
        
        func updateTrajectory(_ trajectory: Trajectory?, currentTime: Double, showFullTrajectory: Bool) {
            guard let trajectory = trajectory,
                  let trajectoryLayer = trajectoryLayer,
                  let currentPositionLayer = currentPositionLayer,
                  let containerView = containerView else {
                trajectoryLayer?.path = nil
                currentPositionLayer?.path = nil
                return
            }
            
            let bounds = containerView.bounds
            guard bounds.width > 0 && bounds.height > 0 else { return }
            
            // Get the actual video frame within the container (considering aspect ratio)
            guard let playerLayer = playerLayer else { return }
            let videoRect = playerLayer.videoRect
            
            // Create white trajectory path with smoothing
            let path = UIBezierPath()
            var hasStarted = false
            
            // Use smoothed points from trajectory
            let smoothedFrames = trajectory.smoothedPoints
            
            for (index, point) in smoothedFrames.enumerated() {
                // Convert normalized coordinates (0-1) to video frame coordinates
                let displayPoint = CGPoint(
                    x: videoRect.origin.x + (point.x * videoRect.width),
                    y: videoRect.origin.y + (point.y * videoRect.height)
                )
                
                if showFullTrajectory {
                    // Show full trajectory
                    if !hasStarted {
                        path.move(to: displayPoint)
                        hasStarted = true
                    } else {
                        path.addLine(to: displayPoint)
                    }
                } else {
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
            
            // Update current position indicator (yellow dot)
            if let currentFrame = trajectory.frames.first(where: { abs($0.timestamp - currentTime) < 0.05 }) {
                let currentPoint = CGPoint(
                    x: videoRect.origin.x + (currentFrame.boundingBox.midX * videoRect.width),
                    y: videoRect.origin.y + (currentFrame.boundingBox.midY * videoRect.height)
                )
                
                let circlePath = UIBezierPath(arcCenter: currentPoint, radius: 8, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                currentPositionLayer.path = circlePath.cgPath
            } else {
                currentPositionLayer.path = nil
            }
        }
    }
}
