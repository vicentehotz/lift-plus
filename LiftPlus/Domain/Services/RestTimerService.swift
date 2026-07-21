import Foundation
import UserNotifications

/// Timer de descanso baseado em data absoluta: a UI deriva o restante de
/// `endDate − now`, então suspensão do app não desvia o relógio. A notificação
/// local cobre o caso de app em background/fechado.
@Observable
final class RestTimerService {
    private(set) var endDate: Date?
    private static let notificationId = "liftplus.rest.finished"

    var remaining: TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(.now))
    }

    var isExpired: Bool {
        guard let endDate else { return true }
        return endDate <= .now
    }

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func start(duration: TimeInterval, nextExerciseName: String) {
        let end = Date.now.addingTimeInterval(duration)
        endDate = end
        scheduleNotification(at: end, nextExerciseName: nextExerciseName)
    }

    func add(_ seconds: TimeInterval, nextExerciseName: String) {
        guard let current = endDate else { return }
        let end = max(current, .now).addingTimeInterval(seconds)
        endDate = end
        scheduleNotification(at: end, nextExerciseName: nextExerciseName)
    }

    func cancel() {
        endDate = nil
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationId])
    }

    private func scheduleNotification(at date: Date, nextExerciseName: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationId])

        let content = UNMutableNotificationContent()
        content.title = "Descanso concluído"
        content.body = "Próximo: \(nextExerciseName)"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let interval = max(1, date.timeIntervalSince(.now))
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: Self.notificationId, content: content, trigger: trigger))
    }
}
