// LoopFollow
// TrioAnswerWatch.swift

import Foundation
import UserNotifications

/// Speaks up when Trio doesn't answer a bolus or meal. Apple accepting the push only means it took it: with Trio's
/// iPhone off and the watch handling commands, a push Apple holds back or drops reaches nobody, and nothing else
/// tells the sender. No answer doesn't prove nothing was given (the answer can be lost as well), so this asks the
/// user to check first and never sends anything again on its own.
final class TrioAnswerWatch {
    static let shared = TrioAnswerWatch()

    /// Trio's iPhone waits 25 s for its watch before answering "no answer", so a minute covers both ways.
    private let wait: TimeInterval = 60
    /// A check that runs this late (LoopFollow was suspended meanwhile) would only add noise.
    private let staleAfter: TimeInterval = 10 * 60

    private struct Pending {
        let commandType: String
        let summary: String
        let sentAt: Date
        let check: DispatchWorkItem
    }

    private var pending: [UUID: Pending] = [:]

    /// After Apple accepted a bolus or meal that asked for an answer.
    func expect(_ commandType: TRCCommandType, summary: String) {
        onMain {
            let id = UUID()
            let sentAt = Date()
            let check = DispatchWorkItem { [weak self] in self?.check(id) }
            self.pending[id] = Pending(commandType: commandType.rawValue, summary: summary, sentAt: sentAt, check: check)
            DispatchQueue.main.asyncAfter(deadline: .now() + self.wait, execute: check)
        }
    }

    /// Any answer from Trio (success, failure or the iPhone's "no answer"), as it reaches the app.
    func note(_ userInfo: [AnyHashable: Any]) {
        guard userInfo["command_status"] != nil else { return }
        let type = userInfo["command_type"] as? String
        onMain { self.answered(type: type, at: Date()) }
    }

    private func answered(type: String?, at date: Date) {
        // the oldest open command of that type (or of any type, when the answer doesn't say)
        guard let match = pending
            .filter({ (type == nil || $0.value.commandType == type) && $0.value.sentAt <= date })
            .min(by: { $0.value.sentAt < $1.value.sentAt })
        else { return }
        match.value.check.cancel()
        pending[match.key] = nil
    }

    private func check(_ id: UUID) {
        guard let command = pending[id] else { return }
        // an answer shown while LoopFollow was in the background never passed through the app
        UNUserNotificationCenter.current().getDeliveredNotifications { delivered in
            let answer = delivered.first { note in
                let info = note.request.content.userInfo
                guard info["command_status"] != nil, note.date >= command.sentAt else { return false }
                let type = info["command_type"] as? String
                return type == nil || type == command.commandType
            }
            self.onMain {
                guard self.pending.removeValue(forKey: id) != nil else { return }
                if answer != nil { return }
                guard Date().timeIntervalSince(command.sentAt) < self.staleAfter else {
                    LogManager.shared.log(category: .apns, message: "No answer from Trio to the \(command.summary), checked too late to say")
                    return
                }
                LogManager.shared.log(category: .apns, message: "No answer from Trio to the \(command.summary) within \(Int(self.wait)) s")
                self.notifyNoAnswer(command)
            }
        }
    }

    private func notifyNoAnswer(_ command: Pending) {
        let content = UNMutableNotificationContent()
        content.title = "No Confirmation From Trio"
        let time = DateFormatter.localizedString(from: command.sentAt, dateStyle: .none, timeStyle: .short)
        content.body = "Trio hasn't answered the \(command.summary) sent at \(time). It may or may not have been given: check Trio or Nightscout before sending it again."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: "trio-no-answer-\(Int(command.sentAt.timeIntervalSince1970))", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}
