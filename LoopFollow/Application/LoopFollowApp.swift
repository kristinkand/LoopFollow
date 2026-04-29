// LoopFollow
// LoopFollowApp.swift

import SwiftUI

@main
struct LoopFollowApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var telemetryConsentDecisionMade = Storage.shared.telemetryConsentDecisionMade
    @State private var showTelemetryConsent = false

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onOpenURL { url in
                    guard url.scheme == AppGroupID.urlScheme, url.host == "la-tap" else { return }
                    #if !targetEnvironment(macCatalyst)
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: .liveActivityDidForeground, object: nil)
                        }
                    #endif
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    handleTelemetryForeground()
                }
                // Modal sheet, swipe-to-dismiss disabled so the user must
                // pick Yes / No.
                .sheet(isPresented: $showTelemetryConsent) {
                    TelemetryConsentView()
                        .interactiveDismissDisabled()
                }
        }
    }

    /// Foreground entry point for the telemetry feature. See Helpers/Telemetry.swift.
    /// On first foreground after install (or after an update from a pre-telemetry
    /// version) presents the one-time consent sheet. Otherwise hands off to
    /// TelemetryClient.maybeSend(), which is internally rate-limited.
    private func handleTelemetryForeground() {
        if !telemetryConsentDecisionMade.value {
            // Don't reopen if the sheet is already up (e.g. user backgrounded
            // and re-foregrounded mid-decision).
            if !showTelemetryConsent {
                showTelemetryConsent = true
            }
            return
        }
        Task.detached { await TelemetryClient.shared.maybeSend() }
    }
}
