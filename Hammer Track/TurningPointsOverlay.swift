import SwiftUI

// Struktur für Umkehrpunkt-Visualisierung
struct TurningPointVisualization: Identifiable {
    let id = UUID()
    let frameNumber: Int
    let position: CGPoint
    let type: TurningPointType
    let index: Int
}

enum TurningPointType {
    case maximum
    case minimum
    
    var color: Color {
        switch self {
        case .maximum:
            return .red
        case .minimum:
            return .blue
        }
    }
    
    var symbol: String {
        switch self {
        case .maximum:
            return "▲"
        case .minimum:
            return "▼"
        }
    }
}

struct TurningPointsOverlay: View {
    let turningPoints: [TurningPointVisualization]
    let currentFrame: Int
    let videoSize: CGSize
    let showLabels: Bool
    let showConnections: Bool
    
    init(turningPoints: [TurningPointVisualization], 
         currentFrame: Int,
         videoSize: CGSize,
         showLabels: Bool = true,
         showConnections: Bool = true) {
        self.turningPoints = turningPoints
        self.currentFrame = currentFrame
        self.videoSize = videoSize
        self.showLabels = showLabels
        self.showConnections = showConnections
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Verbindungslinien zwischen Punkten
                if showConnections && turningPoints.count > 1 {
                    Path { path in
                        for i in 0..<turningPoints.count {
                            let point = convertToViewCoordinates(
                                turningPoints[i].position,
                                in: geometry.size
                            )
                            
                            if i == 0 {
                                path.move(to: point)
                            } else {
                                path.addLine(to: point)
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.yellow.opacity(0.6), .orange.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(
                            lineWidth: 2,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: [5, 3]
                        )
                    )
                }
                
                // Umkehrpunkte
                ForEach(turningPoints) { point in
                    let viewPosition = convertToViewCoordinates(
                        point.position,
                        in: geometry.size
                    )
                    
                    TurningPointMarker(
                        point: point,
                        isActive: abs(point.frameNumber - currentFrame) < 5,
                        showLabel: showLabels
                    )
                    .position(viewPosition)
                }
            }
        }
    }
    
    private func convertToViewCoordinates(_ normalizedPoint: CGPoint, in viewSize: CGSize) -> CGPoint {
        // Konvertiere normalisierte Koordinaten (0-1) zu View-Koordinaten
        // Beachte: Video-Koordinaten könnten gespiegelt sein
        return CGPoint(
            x: normalizedPoint.x * viewSize.width,
            y: normalizedPoint.y * viewSize.height
        )
    }
}

struct TurningPointMarker: View {
    let point: TurningPointVisualization
    let isActive: Bool
    let showLabel: Bool
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 2) {
            // Hauptmarker
            ZStack {
                // Äußerer Ring (animiert wenn aktiv)
                Circle()
                    .stroke(point.type.color.opacity(0.3), lineWidth: 2)
                    .frame(width: isActive ? 40 : 30, height: isActive ? 40 : 30)
                    .scaleEffect(isAnimating && isActive ? 1.3 : 1.0)
                    .opacity(isAnimating && isActive ? 0.0 : 1.0)
                    .animation(
                        isActive ? 
                        Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false) :
                        .default,
                        value: isAnimating
                    )
                
                // Innerer Kreis
                Circle()
                    .fill(point.type.color)
                    .frame(width: isActive ? 20 : 16, height: isActive ? 20 : 16)
                    .overlay(
                        Text(point.type.symbol)
                            .font(.system(size: isActive ? 12 : 10, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                // Nummer des Umkehrpunkts
                Text("\(point.index)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(3)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.7))
                    )
                    .offset(x: 12, y: -12)
            }
            
            // Label mit Frame-Nummer
            if showLabel {
                VStack(spacing: 0) {
                    Text("Frame \(point.frameNumber)")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                    
                    Text(point.type == .maximum ? "MAX" : "MIN")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(point.type.color)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.7))
                )
            }
        }
        .onAppear {
            if isActive {
                isAnimating = true
            }
        }
        .onChange(of: isActive) { newValue in
            isAnimating = newValue
        }
    }
}

// Hilfs-View für Statistik-Anzeige
struct TurningPointsStatistics: View {
    let turningPoints: [TurningPointVisualization]
    let currentFrame: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Umkehrpunkte")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack {
                Label("\(turningPoints.filter { $0.type == .maximum }.count)", 
                      systemImage: "arrow.up.circle.fill")
                    .foregroundColor(.red)
                
                Label("\(turningPoints.filter { $0.type == .minimum }.count)", 
                      systemImage: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
            }
            .font(.caption)
            
            Text("Frame: \(currentFrame)")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.8))
        )
    }
}

// Preview Provider
struct TurningPointsOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray
            
            TurningPointsOverlay(
                turningPoints: [
                    TurningPointVisualization(
                        frameNumber: 0,
                        position: CGPoint(x: 0.2, y: 0.3),
                        type: .maximum,
                        index: 1
                    ),
                    TurningPointVisualization(
                        frameNumber: 16,
                        position: CGPoint(x: 0.8, y: 0.5),
                        type: .minimum,
                        index: 2
                    ),
                    TurningPointVisualization(
                        frameNumber: 32,
                        position: CGPoint(x: 0.3, y: 0.7),
                        type: .maximum,
                        index: 3
                    )
                ],
                currentFrame: 16,
                videoSize: CGSize(width: 1080, height: 1920)
            )
        }
        .frame(width: 300, height: 500)
    }
}
