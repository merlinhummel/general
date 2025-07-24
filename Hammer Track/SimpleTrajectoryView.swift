import SwiftUI
import AVKit

// MARK: - Simple Trajectory View
struct SimpleTrajectoryView: UIViewRepresentable {
    let player: AVPlayer
    let trajectory: Trajectory?
    @Binding var currentTime: Double
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        
        // Video layer
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect // Keep aspect ratio
        containerView.layer.addSublayer(playerLayer)
        
        // Trajectory layer
        let trajectoryLayer = CAShapeLayer()
        trajectoryLayer.strokeColor = UIColor.red.cgColor
        trajectoryLayer.fillColor = UIColor.clear.cgColor
        trajectoryLayer.lineWidth = 3.0
        containerView.layer.addSublayer(trajectoryLayer)
        
        // Current position dot
        let dotLayer = CAShapeLayer()
        dotLayer.fillColor = UIColor.yellow.cgColor
        containerView.layer.addSublayer(dotLayer)
        
        context.coordinator.containerView = containerView
        context.coordinator.playerLayer = playerLayer
        context.coordinator.trajectoryLayer = trajectoryLayer
        context.coordinator.dotLayer = dotLayer
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.updateLayout()
        context.coordinator.updateTrajectory(trajectory, currentTime: currentTime)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        weak var containerView: UIView?
        weak var playerLayer: AVPlayerLayer?
        weak var trajectoryLayer: CAShapeLayer?
        weak var dotLayer: CAShapeLayer?
        
        func updateLayout() {
            guard let containerView = containerView,
                  let playerLayer = playerLayer,
                  let trajectoryLayer = trajectoryLayer,
                  let dotLayer = dotLayer else { return }
            
            let bounds = containerView.bounds
            playerLayer.frame = bounds
            trajectoryLayer.frame = bounds
            dotLayer.frame = bounds
        }
        
        func updateTrajectory(_ trajectory: Trajectory?, currentTime: Double) {
            guard let trajectory = trajectory,
                  let trajectoryLayer = trajectoryLayer,
                  let dotLayer = dotLayer,
                  let playerLayer = playerLayer else { return }
            
            // Get the actual video rect (where the video is displayed)
            let videoRect = playerLayer.videoRect
            guard videoRect.width > 0 && videoRect.height > 0 else { return }
            
            // Draw trajectory
            let path = UIBezierPath()
            var firstPoint = true
            
            for point in trajectory.smoothedPoints {
                // Convert normalized coordinates (0-1) to screen coordinates
                // Flip Y-axis to match video orientation
                let screenPoint = CGPoint(
                    x: videoRect.origin.x + point.x * videoRect.width,
                    y: videoRect.origin.y + (1.0 - point.y) * videoRect.height  // Flip Y
                )
                
                if firstPoint {
                    path.move(to: screenPoint)
                    firstPoint = false
                } else {
                    path.addLine(to: screenPoint)
                }
            }
            
            trajectoryLayer.path = path.cgPath
            
            // Draw current position
            if let currentFrame = trajectory.frames.first(where: { abs($0.timestamp - currentTime) < 0.1 }) {
                let point = CGPoint(x: currentFrame.boundingBox.midX, y: currentFrame.boundingBox.midY)
                let screenPoint = CGPoint(
                    x: videoRect.origin.x + point.x * videoRect.width,
                    y: videoRect.origin.y + (1.0 - point.y) * videoRect.height  // Flip Y
                )
                
                let dotPath = UIBezierPath(arcCenter: screenPoint, radius: 8, startAngle: 0, endAngle: .pi * 2, clockwise: true)
                dotLayer.path = dotPath.cgPath
                dotLayer.isHidden = false
            } else {
                dotLayer.isHidden = true
            }
        }
    }
}