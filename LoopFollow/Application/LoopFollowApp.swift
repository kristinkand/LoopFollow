// LoopFollow
// LoopFollowApp.swift

import SwiftUI

@main
struct LoopFollowApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject private var telemetryConsentDecisionMade = Storage.shared.telemetryConsentDecisionMade
    @ObservedObject private var storageReady = StorageReadiness.ready
    @State private var showTelemetryConsent = false

    var body: some Scene {
        WindowGroup {
            // Gate the UI on storage readiness so nothing (bootstrap, telemetry
            // consent, onboarding) is built against a poisoned cache. True
            // synchronously on a normal launch; only false briefly while a BFU
            // background launch is foregrounded mid-hydration.
            if storageReady.value {
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
            } else {
                StorageLoadingView()
            }
        }
    }

    /// Presents the one-time consent sheet on first foreground.
    private func handleTelemetryForeground() {
        if !telemetryConsentDecisionMade.value {
            // Don't reopen if the sheet is already up (e.g. user backgrounded
            // and re-foregrounded mid-decision).
            if !showTelemetryConsent {
                showTelemetryConsent = true
            }
        }
    }
}
