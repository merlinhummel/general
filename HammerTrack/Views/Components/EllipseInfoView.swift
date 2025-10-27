import SwiftUI

/// Kompakte Ellipsen-Info-Anzeige für Video-Overlays
struct EllipseInfoOverlay: View {
    let ellipseAngle: Double?
    let ellipseIndex: Int?
    let totalEllipses: Int
    
    var body: some View {
        Group {
            if let angle = ellipseAngle, let index = ellipseIndex, totalEllipses > 0 {
                VStack(spacing: 1) {
                    // Ellipse number
                    Text("E\(index)/\(totalEllipses)")
                        .font(.caption2)
                        .fontWeight(.medium)
                    
                    // Angle with direction indicator
                    HStack(spacing: 2) {
                        // Direction arrow using SF Symbols
                        Image(systemName: angle > 0 ? "arrow.up.right" : "arrow.up.left")
                            .font(.caption2)
                        
                        // Angle value
                        Text("\(String(format: "%.1f", abs(angle)))°")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(angle > 0 ? Color.red : Color.blue, lineWidth: 1)
                        )
                )
                .shadow(radius: 2)
            }
        }
    }
}

/// Erweiterte Ellipsen-Info für Steuerelemente
struct EllipseInfoControl: View {
    let ellipseAngle: Double?
    let ellipseIndex: Int?
    let totalEllipses: Int
    
    var body: some View {
        VStack(spacing: 2) {
            if let angle = ellipseAngle, let index = ellipseIndex, totalEllipses > 0 {
                // Ellipse number
                Text("Ellipse \(index)/\(totalEllipses)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // Angle with visual direction indicator
                HStack(spacing: 4) {
                    // Direction arrow
                    Image(systemName: angle > 0 ? "arrow.up.right" : "arrow.up.left")
                        .font(.caption2)
                        .foregroundColor(angle > 0 ? .red : .blue)
                    
                    // Angle value
                    Text(String(format: "%.1f°", abs(angle)))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Direction text
                    Text(angle > 0 ? "rechts" : "links")
                        .font(.caption2)
                        .foregroundColor(angle > 0 ? .red : .blue)
                }
            } else if totalEllipses > 0 {
                Text("Zwischen Ellipsen")
                    .font(.caption2)
                    .foregroundColor(.gray)
            } else {
                Text("Keine Ellipsen erkannt")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview("Overlay") {
    VStack(spacing: 20) {
        EllipseInfoOverlay(ellipseAngle: 12.5, ellipseIndex: 3, totalEllipses: 8)
        EllipseInfoOverlay(ellipseAngle: -8.2, ellipseIndex: 4, totalEllipses: 8)
    }
    .padding()
    .background(Color.black)
}

#Preview("Control") {
    VStack(spacing: 20) {
        EllipseInfoControl(ellipseAngle: 12.5, ellipseIndex: 3, totalEllipses: 8)
        EllipseInfoControl(ellipseAngle: -8.2, ellipseIndex: 4, totalEllipses: 8)
        EllipseInfoControl(ellipseAngle: nil, ellipseIndex: nil, totalEllipses: 0)
    }
    .padding()
}
