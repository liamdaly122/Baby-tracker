import Foundation
import MissionCore
import UIKit
import UserNotifications

/// Turns engine evaluations into local notifications. Nothing runs in the background: rises that
/// happen with the app closed are covered by notifications scheduled for the moment they'll happen.
@MainActor
final class ThresholdNotifier: NSObject, LabourAlerting {
    private let center = UNUserNotificationCenter.current()
    private static let scheduledPrefix = "labour.scheduled."
    private var lastScheduled: [PlannedAlert] = []

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func engineDidUpdate(previousState: LabourState?, input: EngineInput, output: EngineOutput) {
        let thresholds = input.thresholds
        if let rise = LabourAlertPlanner.immediate(
            previousState: previousState,
            output: output,
            region: input.profile.region,
            thresholds: thresholds
        ) {
            if UIApplication.shared.applicationState == .active {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else {
                post(rise, identifier: "labour.rise.\(UUID().uuidString)", after: nil)
            }
        }

        let scheduled = LabourAlertPlanner.scheduled(input: input, output: output)
        guard scheduled != lastScheduled else { return }
        lastScheduled = scheduled
        center.removePendingNotificationRequests(withIdentifiers: (0..<4).map { Self.scheduledPrefix + "\($0)" })
        for (index, alert) in scheduled.enumerated() {
            post(alert, identifier: Self.scheduledPrefix + "\(index)", after: alert.fireAt.timeIntervalSince(input.now))
        }
    }

    func sessionDidEnd() {
        lastScheduled = []
        center.removeAllPendingNotificationRequests()
    }

    private func post(_ alert: PlannedAlert, identifier: String, after delay: TimeInterval?) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        content.threadIdentifier = "labour"
        let trigger = delay.map { UNTimeIntervalNotificationTrigger(timeInterval: max(1, $0), repeats: false) }
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}

extension ThresholdNotifier: UNUserNotificationCenterDelegate {
    /// Shown as a banner even in the foreground: the partner may be on the decoder or the call card.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
