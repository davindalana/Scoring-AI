import Foundation
import CoreMotion

/// Represents a candidate shot event detected by motion heuristics or manual trigger
public struct CandidateShot: Codable, Identifiable {
    public let id: String
    public let sessionId: Int
    public let timestamp: Date
    public let confidence: Double
    public let peakAccelerationG: Double
    public let drawDurationMs: Int
    public let matchedEnd: Int?
    public let matchedArrow: Int?
    public let isManual: Bool

    public init(
        id: String = UUID().uuidString,
        sessionId: Int,
        timestamp: Date = Date(),
        confidence: Double,
        peakAccelerationG: Double,
        drawDurationMs: Int,
        matchedEnd: Int? = nil,
        matchedArrow: Int? = nil,
        isManual: Bool = false
    ) {
        self.id = id
        self.sessionId = sessionId
        self.timestamp = timestamp
        self.confidence = confidence
        self.peakAccelerationG = peakAccelerationG
        self.drawDurationMs = drawDurationMs
        self.matchedEnd = matchedEnd
        self.matchedArrow = matchedArrow
        self.isManual = isManual
    }

    public func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "session_id": sessionId,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "confidence": confidence,
            "peak_acceleration": peakAccelerationG,
            "draw_duration_ms": drawDurationMs,
            "matched_end": matchedEnd as Any,
            "matched_arrow": matchedArrow as Any,
            "is_manual": isManual
        ]
    }
}

/// Algorithmic detector identifying archery arrow release candidates from IMU motion streams
public class ShotDetector {
    // Configuration thresholds
    private let peakThresholdG: Double = 3.2          // Minimum acceleration shock spike
    private let minimumHoldDurationMs: Int = 1200     // Minimum anchor/aiming hold duration
    private let maximumHoldDurationMs: Int = 10000    // Max hold window before reset
    private let refractoryPeriodMs: Int = 2200        // Lockout window after shot release

    // State tracking
    private var isAiming: Bool = false
    private var aimStartTime: Date?
    private var lastShotTime: Date = Date.distantPast
    private var recentAccelerations: [(time: Date, magnitude: Double)] = []

    public var onShotDetected: ((CandidateShot) -> Void)?

    public init() {}

    /// Process high-frequency accelerometer and gyroscope sample (50-100Hz)
    public func processSample(acceleration: CMAcceleration, rotation: CMRotationRate, sessionId: Int) {
        let now = Date()

        // 1. Check refractory lockout
        if now.timeIntervalSince(lastShotTime) * 1000.0 < Double(refractoryPeriodMs) {
            return
        }

        // 2. Compute 3-axis net acceleration magnitude (in Gs)
        let totalAccelG = sqrt(acceleration.x * acceleration.x +
                               acceleration.y * acceleration.y +
                               acceleration.z * acceleration.z)

        // Compute rotation magnitude (rad/sec)
        let totalRot = sqrt(rotation.x * rotation.x +
                            rotation.y * rotation.y +
                            rotation.z * rotation.z)

        recentAccelerations.append((now, totalAccelG))
        if recentAccelerations.count > 100 { // Keep last 1-2 seconds
            recentAccelerations.removeFirst()
        }

        // 3. Aiming / Hold Phase Detection: Low rotational movement and stable acceleration
        let isQuiet = (totalRot < 1.2) && (abs(totalAccelG - 1.0) < 0.45)

        if isQuiet {
            if !isAiming {
                isAiming = true
                aimStartTime = now
            }
        } else {
            // If movement is excessively erratic and not a release, reset aim if hold was too short
            if isAiming, let start = aimStartTime {
                let holdDuration = now.timeIntervalSince(start) * 1000.0
                if totalAccelG < peakThresholdG && holdDuration > Double(maximumHoldDurationMs) {
                    isAiming = false
                    aimStartTime = nil
                }
            }
        }

        // 4. Arrow Release Spike Detection
        if totalAccelG >= peakThresholdG {
            let holdDurationMs: Int
            let confidence: Double

            if isAiming, let start = aimStartTime {
                let duration = Int(now.timeIntervalSince(start) * 1000.0)
                holdDurationMs = duration

                if duration >= minimumHoldDurationMs && duration <= maximumHoldDurationMs {
                    // Ideal archery release profile: calm hold followed by high-G snap
                    let stabilityScore = min(1.0, Double(duration) / 3500.0)
                    let peakScore = min(1.0, totalAccelG / 6.0)
                    confidence = Double(round(100 * (0.6 * stabilityScore + 0.4 * peakScore)) / 100)
                } else {
                    confidence = 0.65
                }
            } else {
                // Release detected without identified calm hold (e.g. quick release)
                holdDurationMs = 1500
                confidence = 0.55
            }

            // Trigger candidate shot
            lastShotTime = now
            isAiming = false
            aimStartTime = nil

            let shot = CandidateShot(
                sessionId: sessionId,
                timestamp: now,
                confidence: confidence,
                peakAccelerationG: Double(round(totalAccelG * 100) / 100),
                drawDurationMs: holdDurationMs,
                isManual: false
            )

            onShotDetected?(shot)
        }
    }

    /// Reset internal state
    public func reset() {
        isAiming = false
        aimStartTime = nil
        lastShotTime = Date.distantPast
        recentAccelerations.removeAll()
    }
}
