import Foundation
import Flutter
import WatchConnectivity

/// Manages WCSession on the host iOS app and bridges shot events & controls to Flutter via Platform Channels
public class WatchBridgeManager: NSObject, WCSessionDelegate, FlutterStreamHandler {
    public static let shared = WatchBridgeManager()

    private let methodChannelName = "archery/watch_control"
    private let eventChannelName = "archery/watch_events"

    private var eventSink: FlutterEventSink?
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?

    private override init() {
        super.init()
    }

    /// Setup method & event channels with Flutter binary messenger
    public func setup(with binaryMessenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: binaryMessenger)
        eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: binaryMessenger)

        methodChannel?.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call: call, result: result)
        }

        eventChannel?.setStreamHandler(self)

        activateWCSession()
    }

    private func activateWCSession() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Flutter MethodChannel Handler

    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getWatchStatus":
            result(getWatchStatusMap())

        case "startWatchSession":
            guard let args = call.arguments as? [String: Any],
                  let sessionId = args["session_id"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "session_id required", details: nil))
                return
            }
            let athleteName = args["athlete_name"] as? String
            let currentEnd = args["current_end"] as? Int ?? 1

            sendSessionMessage(action: "START_SESSION", payload: [
                "session_id": sessionId,
                "athlete_name": athleteName as Any,
                "current_end": currentEnd
            ])
            result(true)

        case "endWatchSession":
            sendSessionMessage(action: "END_SESSION", payload: [:])
            result(true)

        case "updateSessionState":
            guard let args = call.arguments as? [String: Any],
                  let currentEnd = args["current_end"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "current_end required", details: nil))
                return
            }
            sendSessionMessage(action: "UPDATE_SESSION_STATE", payload: [
                "current_end": currentEnd
            ])
            result(true)

        case "simulateShot":
            // Allows testing shot detection from simulator or UI
            let args = call.arguments as? [String: Any]
            let sessionId = args?["session_id"] as? Int ?? 1
            let confidence = args?["confidence"] as? Double ?? 0.92
            let peakG = args?["peak_acceleration"] as? Double ?? 4.8
            let durationMs = args?["draw_duration_ms"] as? Int ?? 3200

            let simulatedShot: [String: Any] = [
                "id": UUID().uuidString,
                "session_id": sessionId,
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "confidence": confidence,
                "peak_acceleration": peakG,
                "draw_duration_ms": durationMs,
                "matched_end": NSNull(),
                "matched_arrow": NSNull(),
                "is_manual": false
            ]

            emitEvent(name: "shot_detected", data: simulatedShot)
            result(simulatedShot)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func getWatchStatusMap() -> [String: Any] {
        guard WCSession.isSupported() else {
            return [
                "is_supported": false,
                "is_paired": false,
                "is_app_installed": false,
                "is_reachable": false
            ]
        }
        let session = WCSession.default
        return [
            "is_supported": true,
            "is_paired": session.isPaired,
            "is_app_installed": session.isWatchAppInstalled,
            "is_reachable": session.isReachable
        ]
    }

    private func sendSessionMessage(action: String, payload: [String: Any]) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }

        var message = payload
        message["action"] = action

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] _ in
                // Fallback to updateApplicationContext
                try? WCSession.default.updateApplicationContext(message)
            }
        } else {
            try? WCSession.default.updateApplicationContext(message)
        }
    }

    private func emitEvent(name: String, data: Any) {
        DispatchQueue.main.async { [weak self] in
            let eventPayload: [String: Any] = [
                "event": name,
                "data": data
            ]
            self?.eventSink?(eventPayload)
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        emitEvent(name: "watch_status_changed", data: getWatchStatusMap())
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    // MARK: - WCSessionDelegate Methods

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        emitEvent(name: "watch_status_changed", data: getWatchStatusMap())
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        emitEvent(name: "watch_reachability_changed", data: ["is_reachable": session.isReachable])
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate for multi-watch support
        WCSession.default.activate()
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleIncomingWatchPayload(message)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        handleIncomingWatchPayload(userInfo)
    }

    private func handleIncomingWatchPayload(_ payload: [String: Any]) {
        guard let type = payload["type"] as? String else { return }

        if type == "SHOT_DETECTED", let shotData = payload["shot"] as? [String: Any] {
            emitEvent(name: "shot_detected", data: shotData)
        }
    }
}
