import Foundation

struct ShotEventData {
    let id: UUID
    let score: String
    let peakG: Double
    let holdSec: Double
    let timestamp: Date
}

/// Algorithmic recoil impulse detector identifying bow release shock.
class ShotDetector {
    var thresholdG: Double = 2.8
    var onShot: ((ShotEventData) -> Void)?

    private var isAiming = false
    private var aimStartTime: Double = 0.0
    private var lastShotTime: Double = 0.0

    func processSample(accelerationG: Double, timestamp: Double) {
        // Aiming hold phase check (stable acceleration near 1G)
        if abs(accelerationG - 1.0) < 0.25 {
            if !isAiming {
                isAiming = true
                aimStartTime = timestamp
            }
        }

        // Release shock impulse trigger
        if accelerationG > thresholdG && (timestamp - lastShotTime > 2.0) {
            let holdDuration = isAiming && aimStartTime > 0 ? (timestamp - aimStartTime) : 3.0

            if holdDuration >= 0.8 {
                let suggested = holdDuration > 2.5 ? (accelerationG > 3.5 ? "10" : "9") : "8"
                let shot = ShotEventData(
                    id: UUID(),
                    score: suggested,
                    peakG: accelerationG,
                    holdSec: holdDuration,
                    timestamp: Date()
                )

                lastShotTime = timestamp
                isAiming = false
                aimStartTime = 0.0
                onShot?(shot)
            }
        }
    }
}
