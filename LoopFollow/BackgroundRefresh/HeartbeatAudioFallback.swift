// LoopFollow
// HeartbeatAudioFallback.swift

import Foundation
import UIKit

/// Bluetooth heartbeat -> Silent Tune fallback.
///
/// With a Bluetooth heartbeat, LoopFollow is suspended between beats and only the
/// device wakes it. If the heartbeat stops, nothing wakes the app again, so a
/// "switch after 6 minutes" timer could never fire. Instead the fallback is checked
/// whenever LoopFollow gets to run anyway: when it goes to the background (for
/// example after being opened from an "App inactive" notification) and when iOS
/// runs a Background App Refresh. If the heartbeat is overdue at that moment, the
/// silent tune is started to keep LoopFollow refreshing. The first heartbeat that
/// arrives stops it again, so the silent tune only runs while the heartbeat is
/// missing.
final class HeartbeatAudioFallback {
    static let shared = HeartbeatAudioFallback()
    private init() {}

    /// True while the silent tune is running as a heartbeat fallback. Main-queue only.
    private(set) var isActive = false

    /// The heartbeat counts as missing once this many expected intervals have passed.
    private let overdueFactor = 1.2

    /// Fallback interval when the device doesn't report one (Dexcom is 5 minutes).
    private let defaultInterval: TimeInterval = 5 * 60

    /// Only for the Bluetooth modes, and only when the setting is on.
    var isEnabled: Bool {
        Storage.shared.backgroundRefreshType.value.isBluetooth
            && Storage.shared.bleSilentTuneFallback.value
    }

    /// True when no heartbeat has arrived for longer than expected (or none at all yet).
    var isHeartbeatOverdue: Bool {
        guard isEnabled else { return false }
        let interval = BLEManager.shared.expectedHeartbeatInterval() ?? defaultInterval
        guard let last = BLEManager.shared.lastHeartbeatDate() else { return true }
        return Date().timeIntervalSince(last) > interval * overdueFactor
    }

    /// Starts the silent tune if the heartbeat is overdue. Call when the app is (about
    /// to be) in the background and has a moment to run.
    /// - Parameter completion: Called on the main queue; true if the fallback is running.
    func evaluate(reason: String, completion: ((Bool) -> Void)? = nil) {
        onMain {
            guard self.isEnabled, self.isHeartbeatOverdue,
                  let backgroundTask = MainViewController.shared?.backgroundTask
            else {
                completion?(false)
                return
            }
            if self.isActive, backgroundTask.isPlaying {
                completion?(true)
                return
            }

            LogManager.shared.log(category: .bluetooth, message: "Heartbeat overdue (\(reason)), starting Silent Tune as fallback")
            self.isActive = true
            BackgroundRefreshManager.shared.scheduleRefresh()
            backgroundTask.restartAudio(reason: "heartbeat fallback: \(reason)") { success in
                LogManager.shared.log(
                    category: .bluetooth,
                    message: success ? "Silent Tune fallback running" : "Silent Tune fallback could not start"
                )
                if !success { self.isActive = false }
                completion?(success)
            }
        }
    }

    /// A heartbeat arrived: Bluetooth is back, so the fallback is no longer needed.
    func heartbeatReceived() {
        stop(reason: "heartbeat is back")
    }

    /// Stops the fallback if it is running.
    func stop(reason: String) {
        onMain {
            guard self.isActive else { return }
            self.isActive = false
            MainViewController.shared?.backgroundTask.stopBackgroundTask()
            LogManager.shared.log(category: .bluetooth, message: "Silent Tune fallback stopped (\(reason))")
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
