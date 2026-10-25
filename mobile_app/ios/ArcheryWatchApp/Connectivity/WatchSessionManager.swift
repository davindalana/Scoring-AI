import Foundation
import WatchConnectivity

/// Manages bidirectional communication between Apple Watch and host iPhone app
public class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    public static let shared = WatchSessionManager()

    @Published public var isSessionActive: Bool = false
    @Published public var isPhoneReachable: Bool = false
    @Published public var activeSessionId: Int?
    @Published public var athleteName: String?
    @Published public var currentEnd: Int = 1

    public var onRemoteStartSession: ((Int, String?) -> Void)?
    public var onRemoteEndSession: (() -> Void)?

    private override init() {
        super.init()
    }

    public func activate() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    /// Send candidate shot to iPhone (real-time message with guaranteed transferUserInfo fallback)
    public func sendShotEvent(_ shot: CandidateShot) {
        guard WCSession.default.activationState == .activated else { return }

        let payload: [String: Any] = [
            "type": "SHOT_DETECTED",
            "shot": shot.toDictionary()
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil) { [weak self] _ in
                // If real-time message fails, fall back to guaranteed queued transfer
                self?.queueGuaranteedTransfer(payload)
            }
        } else {
            queueGuaranteedTransfer(payload)
        }
    }

    private func queueGuaranteedTransfer(_ payload: [String: Any]) {
        WCSession.default.transferUserInfo(payload)
    }

    // MARK: - WCSessionDelegate Methods

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingMessage(message)
    }

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        handleIncomingMessage(applicationContext)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingMessage(userInfo)
    }

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }

        DispatchQueue.main.async {
            switch action {
            case "START_SESSION":
                if let sessionId = message["session_id"] as? Int {
                    self.activeSessionId = sessionId
                    self.athleteName = message["athlete_name"] as? String
                    self.currentEnd = message["current_end"] as? Int ?? 1
                    self.isSessionActive = true
                    self.onRemoteStartSession?(sessionId, self.athleteName)
                }
            case "END_SESSION":
                self.isSessionActive = false
                self.activeSessionId = nil
                self.onRemoteEndSession?()
            case "UPDATE_SESSION_STATE":
                if let currentEnd = message["current_end"] as? Int {
                    self.currentEnd = currentEnd
                }
            default:
                break
            }
        }
    }
}
