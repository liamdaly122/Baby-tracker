#if canImport(WatchConnectivity)
    import Foundation
    import MissionCore
    import WatchConnectivity

    /// Carries `SyncMessage`s between the phone and the watch. Taps go two ways at once: an instant
    /// message when the other device is reachable, and a queued copy that arrives even if it isn't
    /// running. Duplicates are harmless because the log dedupes by event ID.
    @MainActor
    public final class SyncTransport: NSObject {
        public var onMessage: ((SyncMessage) -> Void)?
        /// Called when the other device becomes reachable, to catch up.
        public var onReachable: (() -> Void)?
        private let session: WCSession?
        /// Queued messages sent before the session was ready to take them. Sent once it is, so a
        /// tap in the first second after launch still reaches the other device.
        private var waiting: [SyncMessage] = []
        private var waitingContext: SyncMessage?

        override public init() {
            session = WCSession.isSupported() ? WCSession.default : nil
            super.init()
        }

        public func activate() {
            session?.delegate = self
            session?.activate()
        }

        public var isReachable: Bool { session?.isReachable ?? false }

        /// Sends now if the other device is reachable, and queues a copy unless `queued` is false.
        public func send(_ message: SyncMessage, queued: Bool = true) {
            guard let session, session.activationState == .activated, canSend(session) else {
                if queued {
                    waiting.append(message)
                }
                return
            }
            guard let payload = try? message.payload() else { return }
            if session.isReachable {
                session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
            }
            if queued {
                session.transferUserInfo(payload)
            }
        }

        /// The latest state for the other device, replacing the last one sent this way.
        public func setContext(_ message: SyncMessage) {
            guard let session, session.activationState == .activated, canSend(session) else {
                waitingContext = message
                return
            }
            guard let payload = try? message.payload() else { return }
            try? session.updateApplicationContext(payload)
        }

        /// Sends what was held back while the session wasn't ready.
        private func flush() {
            guard let session, session.activationState == .activated, canSend(session) else { return }
            let held = waiting
            waiting = []
            for message in held {
                send(message)
            }
            if let context = waitingContext {
                waitingContext = nil
                setContext(context)
            }
        }

        /// The context the other device last sent, for a cold start.
        public var receivedContext: SyncMessage? {
            session.flatMap { SyncMessage(payload: $0.receivedApplicationContext) }
        }

        private func canSend(_ session: WCSession) -> Bool {
            #if os(iOS)
                session.isPaired && session.isWatchAppInstalled
            #else
                true
            #endif
        }

        private func deliver(_ message: SyncMessage?) {
            if let message {
                onMessage?(message)
            }
        }
    }

    extension SyncTransport: WCSessionDelegate {
        nonisolated public func session(
            _ session: WCSession,
            activationDidCompleteWith activationState: WCSessionActivationState,
            error: Error?
        ) {
            let context = SyncMessage(payload: session.receivedApplicationContext)
            Task { @MainActor in
                self.deliver(context)
                self.flush()
                self.onReachable?()
            }
        }

        nonisolated public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
            let decoded = SyncMessage(payload: message)
            Task { @MainActor in self.deliver(decoded) }
        }

        nonisolated public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
            let decoded = SyncMessage(payload: userInfo)
            Task { @MainActor in self.deliver(decoded) }
        }

        nonisolated public func session(
            _ session: WCSession,
            didReceiveApplicationContext applicationContext: [String: Any]
        ) {
            let decoded = SyncMessage(payload: applicationContext)
            Task { @MainActor in self.deliver(decoded) }
        }

        nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
            let reachable = session.isReachable
            Task { @MainActor in
                if reachable {
                    self.flush()
                    self.onReachable?()
                }
            }
        }

        #if os(iOS)
            /// The watch app was installed or removed: anything sent before it was installed was
            /// dropped, so catch up.
            nonisolated public func sessionWatchStateDidChange(_ session: WCSession) {
                let installed = session.isPaired && session.isWatchAppInstalled
                Task { @MainActor in
                    if installed {
                        self.flush()
                        self.onReachable?()
                    }
                }
            }

            nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {}

            nonisolated public func sessionDidDeactivate(_ session: WCSession) {
                // A different watch was paired: start talking to it.
                session.activate()
            }
        #endif
    }
#endif
