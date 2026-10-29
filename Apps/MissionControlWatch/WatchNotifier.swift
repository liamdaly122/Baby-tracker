import Foundation
import MissionCore
import UserNotifications
import WatchKit

/// The watch's labour alerts. Same planner and the same identifiers as the phone, so one change
/// buzzes once: a phone alert forwarded to the wrist and the watch's own share an identifier.
@MainActor
final class WatchNotifier: NSObject {
    private let center = UNUserNotificationCenter.current()
    private var lastScheduled: [PlannedAlert] = []
    private var planning: Task<Void, Never>?

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func update(
        sessionID: UUID, previous: EngineStateSnapshot?, input: EngineInput, output: EngineOutput, watersBrokeAt: Date?
    ) {
        let immediate = LabourAlertPlanner.immediate(previous: previous, output: output, region: input.profile.region)
        if !immediate.isEmpty {
            if WKApplication.shared().applicationState == .active {
                WKInterfaceDevice.current().play(.notification)
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
        planning = Task { [previous = planning] in
            await previous?.value
            let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: pending)
            for alert in scheduled {
                post(alert, sessionID: sessionID, after: alert.fireAt.timeIntervalSince(input.now))
            }
        }
    }

    func cancel(sessionID: UUID) {
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
        content.interruptionLevel = alert.level == .timeSensitive ? .timeSensitive : .active
        let trigger = delay.map { UNTimeIntervalNotificationTrigger(timeInterval: max(1, $0), repeats: false) }
        center.add(
            UNNotificationRequest(
                identifier: alert.identifier(sessionID: sessionID), content: content, trigger: trigger))
    }
}

extension WatchNotifier: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
