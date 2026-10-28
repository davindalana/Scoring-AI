import Foundation
import WatchConnectivity

/// Manages bidirectional WatchConnectivity sessions between Apple Watch and Mobile Phone.
class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var isReachable = false
    @Published var currentEnd: Int = 1
    @Published var totalEnds: Int = 10
    @Published var totalScore: Int = 0
    @Published var athleteName: String = "Athlete"

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    /// Transmit detected shot event to phone app
    func sendShotEvent(score: String, peakG: Double, holdSec: Double, heartRate: Int) {
        guard WCSession.default.isReachable else { return }

        let payload: [String: Any] = [
            "type": "SHOT_DETECTED",
            "score": score,
            "peak_g": peakG,
            "hold_duration": holdSec,
            "heart_rate": heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]

        WCSession.default.sendMessage(payload, replyHandler: nil) { error in
            print("Failed to send shot event: \(error.localizedDescription)")
        }
    }

    /// Send wrist score selection to phone
    func sendScoreInput(score: String) {
        guard WCSession.default.isReachable else { return }

        let payload: [String: Any] = [
            "type": "SCORE_INPUT",
            "score": score,
            "timestamp": Date().timeIntervalSince1970
        ]

        WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }

    /// Receive updated session scorecard from phone
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let end = message["current_end"] as? Int {
                self.currentEnd = end
            }
            if let total = message["total_score"] as? Int {
                self.totalScore = total
            }
            if let name = message["athlete_name"] as? String {
                self.athleteName = name
            }
        }
    }
}
