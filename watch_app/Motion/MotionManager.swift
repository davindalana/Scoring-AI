import Foundation
import CoreMotion
import Combine

/// Captures high-frequency CoreMotion sensor data on Apple Watch for archery recoil analysis.
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let shotDetector = ShotDetector()

    @Published var isDetecting = false
    @Published var currentG: Double = 1.0
    @Published var heartRate: Int = 115
    @Published var lastShot: ShotEventData?

    init() {
        shotDetector.onShot = { [weak self] shot in
            DispatchQueue.main.async {
                self?.lastShot = shot
                WatchSessionManager.shared.sendShotEvent(
                    score: shot.score,
                    peakG: shot.peakG,
                    holdSec: shot.holdSec,
                    heartRate: self?.heartRate ?? 115
                )
            }
        }
    }

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 100.0 // 100Hz sampling
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }

            let userAcc = motion.userAcceleration
            let totalG = sqrt(userAcc.x * userAcc.x + userAcc.y * userAcc.y + userAcc.z * userAcc.z)
            self.currentG = totalG
            self.shotDetector.processSample(accelerationG: totalG, timestamp: Date().timeIntervalSince1970)
        }
        isDetecting = true
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        isDetecting = false
    }
}
