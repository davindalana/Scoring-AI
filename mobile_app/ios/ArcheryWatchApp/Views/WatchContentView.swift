import SwiftUI

struct WatchContentView: View {
    @StateObject private var motionManager = MotionManager()
    @ObservedObject private var sessionManager = WatchSessionManager.shared

    @State private var showingPermissionAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header status bar
                HStack {
                    Circle()
                        .fill(motionManager.isRecording ? Color.green : (sessionManager.isPhoneReachable ? Color.yellow : Color.gray))
                        .frame(width: 8, height: 8)
                    Text(motionManager.isRecording ? "RECORDING" : (sessionManager.isPhoneReachable ? "SYNCED" : "OFFLINE"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(motionManager.isRecording ? .green : .secondary)
                    Spacer()
                    if sessionManager.currentEnd > 0 {
                        Text("END \(sessionManager.currentEnd)")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.2))
                            .foregroundColor(.yellow)
                            .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 4)

                Divider()

                // Shot counter card
                VStack(spacing: 2) {
                    Text("\(motionManager.detectedShotsCount)")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundColor(.yellow)
                    Text("SHOTS DETECTED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    if let lastShot = motionManager.lastDetectedShot {
                        Text("Last: \(String(format: "%.1f", lastShot.peakAccelerationG))G (\(Int(lastShot.confidence * 100))%)")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)

                // Session Start/Stop Action
                if motionManager.isRecording {
                    Button(action: {
                        motionManager.stopSession()
                    }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    }
                    .background(Color.red)
                    .cornerRadius(8)
                } else {
                    Button(action: {
                        motionManager.requestAuthorization { granted in
                            let sId = sessionManager.activeSessionId ?? 1
                            motionManager.startSession(sessionId: sId)
                        }
                    }) {
                        HStack {
                            Image(systemName: "record.circle")
                            Text("Start Shooting")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                    }
                    .background(Color.yellow)
                    .cornerRadius(8)
                }

                // Action Buttons: Manual Shot & Reset
                HStack(spacing: 6) {
                    Button(action: {
                        motionManager.recordManualShot()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Manual")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                    }
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)

                    Button(action: {
                        motionManager.resetShotCount()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.red)
                    }
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear {
            sessionManager.activate()

            // Wire up motion shot events to watch connectivity
            motionManager.onShotEvent = { shot in
                sessionManager.sendShotEvent(shot)
            }

            sessionManager.onRemoteStartSession = { sessionId, athlete in
                motionManager.startSession(sessionId: sessionId)
            }

            sessionManager.onRemoteEndSession = {
                motionManager.stopSession()
            }
        }
    }
}
