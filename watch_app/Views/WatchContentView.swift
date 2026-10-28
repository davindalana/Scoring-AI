import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var motionManager: MotionManager
    @EnvironmentObject var sessionManager: WatchSessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header Bar
                HStack {
                    Circle()
                        .fill(sessionManager.isReachable ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text("END \(sessionManager.currentEnd)/\(sessionManager.totalEnds)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    Spacer()
                    Text("❤️ \(motionManager.heartRate)")
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                // Total Score Readout
                VStack(spacing: 2) {
                    Text("TOTAL SCORE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("\(sessionManager.totalScore)")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                }

                // Quick Wrist Score Entry
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    ForEach(["X", "10", "9", "8", "7", "6", "5", "M"], id: \.self) { val in
                        Button(action: {
                            sessionManager.sendScoreInput(score: val)
                            WKInterfaceDevice.current().play(.click)
                        }) {
                            Text(val)
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity, minHeight: 28)
                                .background(buttonColor(val))
                                .foregroundColor(buttonTextColor(val))
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.top, 4)

                // Motion Detection Toggle
                Button(action: {
                    if motionManager.isDetecting {
                        motionManager.stopMonitoring()
                    } else {
                        motionManager.startMonitoring()
                    }
                }) {
                    HStack {
                        Image(systemName: motionManager.isDetecting ? "waveform.path.ecg" : "pause.circle")
                        Text(motionManager.isDetecting ? "Detection Armed" : "Arm Shot Sensor")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(motionManager.isDetecting ? Color.green.opacity(0.3) : Color.gray.opacity(0.3))
                    .cornerRadius(8)
                }
            }
            .padding(4)
        }
    }

    private func buttonColor(_ val: String) -> Color {
        switch val {
        case "X", "10": return Color.yellow
        case "9": return Color.orange
        case "8", "7": return Color.red
        case "6", "5": return Color.blue
        default: return Color(.darkGray)
        }
    }

    private func buttonTextColor(_ val: String) -> Color {
        return (val == "X" || val == "10" || val == "9") ? .black : .white
    }
}
