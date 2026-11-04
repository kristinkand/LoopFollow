// LoopFollow
// WeekendProfileView.swift

import SwiftUI

/// Remotely starts or stops Trio's "Profile" feature (internally still called Weekend Profile in
/// Trio's own code and on Nightscout, hence the type name here) -- the "second profile" toggle in
/// Trio's Adjustments screen. Unlike Overrides, there's no preset to pick or target/duration to set
/// here: Profile's own name, target, and basal/ISF schedule are already configured in the app, so
/// this view only flips it on or off. `weekendProfileActive` reflects whether the currently active
/// Nightscout entry was posted by Profile specifically (enteredBy == "Trio Weekend Profile"), as
/// opposed to a real Override that happens to also be running -- see
/// `MainViewController.processNSOverrides`.
struct WeekendProfileView: View {
    @Environment(\.presentationMode) private var presentationMode
    private let pushNotificationManager = PushNotificationManager()

    @ObservedObject var device = Storage.shared.device
    @ObservedObject var overrideNote = Observable.shared.override
    @ObservedObject var weekendProfileActive = Observable.shared.weekendProfileActive

    @State private var showAlert: Bool = false
    @State private var alertType: AlertType? = nil
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil

    enum AlertType {
        case confirmStart
        case confirmStop
        case statusSuccess
        case statusFailure
    }

    var body: some View {
        NavigationView {
            VStack {
                if device.value != "Trio" {
                    ErrorMessageView(
                        message: "Remote commands are currently only available for Trio."
                    )
                } else {
                    Form {
                        if weekendProfileActive.value {
                            Section(header: Text("Profile")) {
                                HStack {
                                    Text("Status")
                                    Spacer()
                                    Text(overrideNote.value ?? "Active")
                                        .foregroundColor(.secondary)
                                }
                                Button {
                                    alertType = .confirmStop
                                    showAlert = true
                                } label: {
                                    HStack {
                                        Text("Stop Profile")
                                        Spacer()
                                        Image(systemName: "xmark.app")
                                            .font(.title)
                                    }
                                }
                                .tint(.red)
                            }
                        } else {
                            Section(header: Text("Profile")) {
                                Text("Profile is not currently active.")
                                    .foregroundColor(.secondary)
                                Button {
                                    alertType = .confirmStart
                                    showAlert = true
                                } label: {
                                    HStack {
                                        Text("Start Profile")
                                        Spacer()
                                        Image(systemName: "arrow.right.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }

                        Section {
                            Text(
                                "Uses the name, target, and basal/ISF schedule already saved in Trio's Adjustments \u{2192} Profile screen. This only turns it on or off remotely -- it can't change its settings, and it has no effect if Profile hasn't been configured and saved at least once in the app."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }

                    if isLoading {
                        ProgressView("Please wait...")
                            .padding()
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showAlert) {
                switch alertType {
                case .confirmStart:
                    return Alert(
                        title: Text("Start Profile"),
                        message: Text("Do you want to remotely start Profile?"),
                        primaryButton: .default(Text("Confirm"), action: {
                            startWeekendProfile()
                        }),
                        secondaryButton: .cancel()
                    )
                case .confirmStop:
                    return Alert(
                        title: Text("Stop Profile"),
                        message: Text("Are you sure you want to stop Profile?"),
                        primaryButton: .default(Text("Confirm"), action: {
                            stopWeekendProfile()
                        }),
                        secondaryButton: .cancel()
                    )
                case .statusSuccess:
                    return Alert(
                        title: Text("Status"),
                        message: Text(statusMessage ?? ""),
                        dismissButton: .default(Text("OK"), action: {
                            presentationMode.wrappedValue.dismiss()
                        })
                    )
                case .statusFailure:
                    return Alert(
                        title: Text("Status"),
                        message: Text(statusMessage ?? "An error occurred."),
                        dismissButton: .default(Text("OK"))
                    )
                case .none:
                    return Alert(title: Text("Unknown Alert"))
                }
            }
        }
    }

    // MARK: - Functions

    private func startWeekendProfile() {
        isLoading = true

        pushNotificationManager.sendStartWeekendProfilePushNotification { success, errorMessage in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.statusMessage = "Start Profile command successfully sent."
                    self.alertType = .statusSuccess
                    LogManager.shared.log(category: .apns, message: "sendStartWeekendProfilePushNotification succeeded")
                } else {
                    self.statusMessage = errorMessage ?? "Failed to send Start Profile command."
                    self.alertType = .statusFailure
                    LogManager.shared.log(category: .apns, message: "sendStartWeekendProfilePushNotification failed. Error: \(errorMessage ?? "unknown error")")
                }
                self.showAlert = true
            }
        }
    }

    private func stopWeekendProfile() {
        isLoading = true

        pushNotificationManager.sendStopWeekendProfilePushNotification { success, errorMessage in
            DispatchQueue.main.async {
                self.isLoading = false
                if success {
                    self.statusMessage = "Stop Profile command successfully sent."
                    self.alertType = .statusSuccess
                    LogManager.shared.log(category: .apns, message: "sendStopWeekendProfilePushNotification succeeded")
                } else {
                    self.statusMessage = errorMessage ?? "Failed to send Stop Profile command."
                    self.alertType = .statusFailure
                    LogManager.shared.log(category: .apns, message: "sendStopWeekendProfilePushNotification failed. Error: \(errorMessage ?? "unknown error")")
                }
                self.showAlert = true
            }
        }
    }
}
