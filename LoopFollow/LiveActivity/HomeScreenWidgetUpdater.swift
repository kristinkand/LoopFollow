// LoopFollow
// HomeScreenWidgetUpdater.swift

import Foundation

extension MainViewController {
    /// Writes the latest BG value, trend and recent history for the home screen widget.
    func updateHomeScreenWidget(entries: [ShareGlucoseData], deltaBG: Int) {
        guard let latest = entries.last else { return }
        let cutoff = latest.date - WidgetBGStore.historySeconds
        let points = entries
            .filter { $0.date >= cutoff && $0.sgv > 0 }
            .map { WidgetBGPoint(date: $0.date, mgdl: Double($0.sgv)) }

        // Same thresholds as the main screen's colored BG text and graph.
        let thresholds = UnitSettingsStore.shared.effectiveThresholds()

        // Override, temp target and profile, built the same way as for the Live Activity.
        let snapshot = GlucoseSnapshotBuilder.build(from: StorageCurrentGlucoseStateProvider())

        let data = WidgetBGData(
            points: points,
            latestMgdl: Double(latest.sgv),
            deltaMgdl: Double(deltaBG),
            direction: latest.direction,
            readingDate: latest.date,
            unit: PreferredGlucoseUnit.snapshotUnit(),
            lowMgdl: thresholds.low,
            highMgdl: thresholds.high,
            targetMgdl: thresholds.target,
            overrideName: snapshot?.override,
            overrideEndAt: snapshot?.overrideEndAt,
            tempTargetMgdl: snapshot?.tempTargetMgdl,
            tempTargetEndAt: snapshot?.tempTargetEndAt,
            profileName: snapshot?.profileName
        )
        WidgetBGStore.save(data)
    }

    /// Re-sends the current BG data to the widget, e.g. when an override or
    /// temp target starts or ends between readings.
    func refreshHomeScreenWidget() {
        let entries = bgData
        guard entries.count >= 2 else { return }
        let deltaBG = entries[entries.count - 1].sgv - entries[entries.count - 2].sgv
        updateHomeScreenWidget(entries: entries, deltaBG: deltaBG)
    }
}
