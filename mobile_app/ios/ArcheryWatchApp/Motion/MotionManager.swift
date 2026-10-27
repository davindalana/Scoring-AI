import Foundation
import CoreMotion
import HealthKit
import WatchKit

/// Manages watchOS high-frequency motion tracking, HKWorkoutSession for background sensor execution, and shot detection.
public class MotionManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    private let motionManager = CMMotionManager()
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    private let detector = ShotDetector()

    @Published public var isRecording: Bool = false
    @Published public var detectedShotsCount: Int = 0
    @Published public var lastDetectedShot: CandidateShot?
    @Published public var currentHeartRate: Double = 0.0

    public var onShotEvent: ((CandidateShot) -> Void)?

    private var activeSessionId: Int = -1

    public override init() {
        super.init()
        detector.onShotDetected = { [weak self] shot in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.detectedShotsCount += 1
                self.lastDetectedShot = shot
                // Provide haptic feedback so archer feels the confirmed release
                WKInterfaceDevice.current().play(.click)
            }
            self.onShotEvent?(shot)
        }
    }

    /// Request HealthKit authorization for workout session and motion background execution
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, _ in
            completion(success)
        }
    }

    /// Start high-frequency motion recording and active workout session
    public func startSession(sessionId: Int) {
        guard !isRecording else { return }
        self.activeSessionId = sessionId
        self.detectedShotsCount = 0
        detector.reset()

        // 1. Start Workout Session to enable background runtime while wrist is down
        startWorkoutSession()

        // 2. Start high-frequency motion updates (50 Hz)
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 50.0 // 50Hz
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
                guard let self = self, let motion = motion else { return }
                self.detector.processSample(
                    acceleration: motion.userAcceleration,
                    rotation: motion.rotationRate,
                    sessionId: self.activeSessionId
                )
            }
        }

        DispatchQueue.main.async {
            self.isRecording = true
        }
    }

    /// Reset shot count and candidate detector state during active session
    public func resetShotCount() {
        DispatchQueue.main.async {
            self.detectedShotsCount = 0
            self.lastDetectedShot = nil
            self.detector.reset()
            WKInterfaceDevice.current().play(.notification)
        }
    }

    /// Stop motion recording and end workout session
    public func stopSession() {
        guard isRecording else { return }

        motionManager.stopDeviceMotionUpdates()
        stopWorkoutSession()
        detector.reset()

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    /// Manually trigger a shot (e.g. if archer wants to force-record an arrow release)
    public func recordManualShot() {
        let shot = CandidateShot(
            sessionId: activeSessionId,
            timestamp: Date(),
            confidence: 1.0,
            peakAccelerationG: 0.0,
            drawDurationMs: 3000,
            isManual: true
        )
        DispatchQueue.main.async {
            self.detectedShotsCount += 1
            self.lastDetectedShot = shot
            WKInterfaceDevice.current().play(.directionUp)
        }
        self.onShotEvent?(shot)
    }

    // MARK: - HealthKit Workout Session Management

    private func startWorkoutSession() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .archery
        configuration.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()

            workoutSession?.delegate = self
            workoutBuilder?.delegate = self

            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { _, _ in }
        } catch {
            print("Failed to start HKWorkoutSession: \(error.localizedDescription)")
        }
    }

    private func stopWorkoutSession() {
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.workoutBuilder?.finishWorkout { _, _ in }
        }
    }

    // MARK: - HKWorkoutSessionDelegate
    public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}

    // MARK: - HKLiveWorkoutBuilderDelegate
    public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                if let stats = workoutBuilder.statistics(for: quantityType) {
                    let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    let value = stats.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0.0
                    DispatchQueue.main.async {
                        self.currentHeartRate = value
                    }
                }
            }
        }
    }
}
