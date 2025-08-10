import SwiftUI

enum AnalysisMode: String, CaseIterable {
    case trajectory = "Trajektorienwinkel"
    case kneeAngle = "Kniewinkel"
    case both = "Beides"
    
    var description: String {
        switch self {
        case .trajectory:
            return "Misst die Winkel der Hammer-Trajektorie"
        case .kneeAngle:
            return "Misst den Kniewinkel während der Bewegung"
        case .both:
            return "Misst sowohl Trajektorien- als auch Kniewinkel"
        }
    }
}

struct AnalysisOptionsView: View {
    @Binding var selectedMode: AnalysisMode
    @Binding var showOptions: Bool
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Analyse-Modus wählen")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            VStack(spacing: 15) {
                ForEach(AnalysisMode.allCases, id: \.self) { mode in
                    Button(action: {
                        selectedMode = mode
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedMode == mode ? .blue : .gray)
                                    .font(.title2)
                                
                                Text(mode.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMode == mode ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMode == mode ? Color.blue : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 20) {
                Button("Abbrechen") {
                    showOptions = false
                }
                .foregroundColor(.red)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(25)
                
                Button("Analyse starten") {
                    showOptions = false
                    onStart()
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
            }
            .padding(.vertical, 20)
        }
        .frame(maxWidth: 350)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}
