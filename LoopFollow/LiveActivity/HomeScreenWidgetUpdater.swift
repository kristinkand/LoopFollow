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

        let data = WidgetBGData(
            points: points,
            latestMgdl: Double(latest.sgv),
            deltaMgdl: Double(deltaBG),
            direction: latest.direction,
            readingDate: latest.date,
            unit: PreferredGlucoseUnit.snapshotUnit(),
            lowMgdl: thresholds.low,
            highMgdl: thresholds.high,
            targetMgdl: thresholds.target
        )
        WidgetBGStore.save(data)
    }
}
