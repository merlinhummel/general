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
        
        // Setup video layer with aspect fill to fill the container
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill // Changed to fill the container
        containerView.layer.addSublayer(playerLayer)
        
        // Setup trajectory layer for white trajectory overlay
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
        containerView.layer.addSublayer(trajectoryLayer)        
        // Setup current position indicator
        let currentPositionLayer = CAShapeLayer()
        currentPositionLayer.fillColor = UIColor.yellow.cgColor
        currentPositionLayer.strokeColor = UIColor.orange.cgColor
        currentPositionLayer.lineWidth = 1.0  // Reduced from 2.0
        
        // Add shadow for better visibility
        currentPositionLayer.shadowColor = UIColor.black.cgColor
        currentPositionLayer.shadowOpacity = 0.5
        currentPositionLayer.shadowOffset = CGSize(width: 0, height: 0)
        currentPositionLayer.shadowRadius = 2.0
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
            // Get the actual video frame within the container
            guard let playerLayer = playerLayer else { return }
            
            // For aspectFill, we use the full bounds
            let videoRect = bounds
            
            // Debug output
            if trajectory.frames.count > 0 && trajectory.frames.first!.frameNumber % 30 == 0 {
                print("\nTrajectoryView Debug:")
                print("  Container bounds: \(bounds)")
                print("  Video orientation: \(trajectory.videoOrientation)")
                print("  First point: \(trajectory.points.first ?? CGPoint.zero)")
            }
            
            drawTrajectory(in: videoRect, trajectory: trajectory, currentTime: currentTime, showFullTrajectory: showFullTrajectory)
        }
        
        private func drawTrajectory(in videoRect: CGRect, trajectory: Trajectory, currentTime: Double, showFullTrajectory: Bool) {
            guard let trajectoryLayer = trajectoryLayer,
                  let currentPositionLayer = currentPositionLayer else { return }
            
            // Create trajectory path with smoothing
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
                // Flip Y-axis to match video orientation
                let displayPoint = CGPoint(
                    x: videoRect.origin.x + (point.x * videoRect.width),
                    y: videoRect.origin.y + ((1.0 - point.y) * videoRect.height)  // Flip Y
                )
                
                // Validate display point
                guard !displayPoint.x.isNaN && !displayPoint.y.isNaN &&
                      displayPoint.x.isFinite && displayPoint.y.isFinite else { continue }
                
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
            // Find the frame closest to current time
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
    }
}