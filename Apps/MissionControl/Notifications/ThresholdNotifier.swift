import Foundation
import MissionCore
import UIKit
import UserNotifications

/// Turns engine evaluations into local notifications. Nothing runs in the background: rises that
/// happen with the app closed are covered by notifications scheduled for the moment they'll happen.
/// Every labour alert has an identifier from `PlannedAlert.identifier(sessionID:)`, the same one
/// the watch uses, so the two don't both buzz for one change.
@MainActor
final class ThresholdNotifier: NSObject, LabourAlerting {
    private let center = UNUserNotificationCenter.current()
    private var lastScheduled: [PlannedAlert] = []
    /// Re-plans run one after another, so two quick updates can't leave a stale alert behind.
    private var planning: Task<Void, Never>?

    override init() {
        super.init()
        center.delegate = self
    }

    /// Asked before labour (from the home screen) as well as at launch, so the first alert isn't
    /// held up by a permission prompt at 3am.
    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func engineDidUpdate(
        sessionID: UUID, previous: EngineStateSnapshot?, input: EngineInput, output: EngineOutput, watersBrokeAt: Date?
    ) {
        let region = input.profile.region
        let immediate = LabourAlertPlanner.immediate(previous: previous, output: output, region: region)
        if !immediate.isEmpty {
            if UIApplication.shared.applicationState == .active {
                // On screen already: a buzz, not a banner over the advice.
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else {
                for alert in immediate {
                    post(alert, sessionID: sessionID, after: nil)
                }
            }
        }

        let scheduled = LabourAlertPlanner.scheduled(input: input, output: output, watersBrokeAt: watersBrokeAt)
        guard scheduled != lastScheduled else { return }
        lastScheduled = scheduled
        let prefix = LabourAlertPlanner.identifierPrefix(sessionID: sessionID)
        // Drop the old plan before adding the new one, so a rise that no longer applies is gone.
        planning = Task { [previous = planning] in
            await previous?.value
            let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            for alert in scheduled {
                post(alert, sessionID: sessionID, after: alert.fireAt.timeIntervalSince(input.now))
            }
        }
    }

    /// Cancels this labour's alerts only, pending and delivered. Other reminders stay.
    func sessionDidEnd(sessionID: UUID) {
        lastScheduled = []
        let prefix = LabourAlertPlanner.identifierPrefix(sessionID: sessionID)
        planning = Task { [previous = planning] in
            await previous?.value
            let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            let delivered = await center.deliveredNotifications().map(\.request.identifier).filter {
                $0.hasPrefix(prefix)
            }
            center.removeDeliveredNotifications(withIdentifiers: delivered)
        }
    }

    private func post(_ alert: PlannedAlert, sessionID: UUID, after delay: TimeInterval?) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        content.sound = .default
        content.threadIdentifier = "labour"
        // Time sensitive breaks through Sleep and other Focus modes. Needs the Time Sensitive
        // Notifications capability, which the app has.
        content.interruptionLevel = alert.level == .timeSensitive ? .timeSensitive : .active
        let trigger = delay.map { UNTimeIntervalNotificationTrigger(timeInterval: max(1, $0), repeats: false) }
        center.add(
            UNNotificationRequest(
                identifier: alert.identifier(sessionID: sessionID), content: content, trigger: trigger))
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
