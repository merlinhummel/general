import SwiftUI

struct ContentView: View {
    @State private var showCameraTest = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Hammer Track")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 50)
                
                Text("Hammerwurf Analyse")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                VStack(spacing: 20) {
                    NavigationLink(destination: SingleView()) {
                        FeatureButton(
                            title: "Single View",
                            subtitle: "Analysiere ein einzelnes Video",
                            systemImage: "play.rectangle"
                        )
                    }
                    
                    NavigationLink(destination: CompareView()) {
                        FeatureButton(
                            title: "Compare View",
                            subtitle: "Vergleiche zwei Videos",
                            systemImage: "rectangle.stack"
                        )
                    }
                    
                    NavigationLink(destination: LiveView()) {
                        FeatureButton(
                            title: "Live View",
                            subtitle: "Live-Analyse mit der Kamera",
                            systemImage: "camera"
                        )
                    }
                    
                    // Debug Button für Kamera Test
                    Button(action: { showCameraTest = true }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            Text("Kamera Test")
                                .foregroundColor(.orange)
                        }
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange, lineWidth: 2)
                        )
                    }
                    .sheet(isPresented: $showCameraTest) {
                        CameraTestView()
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                Spacer()
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
    }
}

struct FeatureButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    
    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .frame(width: 50)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 3)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}