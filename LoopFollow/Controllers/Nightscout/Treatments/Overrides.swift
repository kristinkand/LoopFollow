// LoopFollow
// Overrides.swift

import Foundation

extension MainViewController {
    /// Marker Trio puts in `enteredBy` for its Profile feature (formerly "Weekend Profile").
    static let weekendProfileEnteredBy = "Trio Weekend Profile"

    /// One override or Profile entry as it will be drawn: `start`/`end` are the clamped graph
    /// span, `trueEnd` the real scheduled end (nil while indefinite).
    private struct OverrideSpan {
        let entry: [String: AnyObject]
        let start: TimeInterval
        let end: TimeInterval
        let trueEnd: TimeInterval?
        let isWeekendProfile: Bool
    }

    func processNSOverrides(entries: [[String: AnyObject]]) {
        overrideGraphData.removeAll()
        var activeOverrideNote: String?
        var activeOverrideEndAt: TimeInterval?
        var activeOverrideIsWeekendProfile = false

        func startDate(of entry: [String: AnyObject]) -> Date? {
            guard let dateStr = (entry["timestamp"] as? String) ?? (entry["created_at"] as? String) else { return nil }
            return NightscoutUtils.parseDate(dateStr)
        }

        let sorted = entries
            .compactMap { entry -> (entry: [String: AnyObject], date: Date)? in
                guard let date = startDate(of: entry) else { return nil }
                return (entry, date)
            }
            .sorted { $0.date < $1.date }

        let now = Date().timeIntervalSince1970
        let minimumFutureDisplayHours = 0.25
        let effectiveFutureHours = max(Storage.shared.predictionToLoad.value, minimumFutureDisplayHours)
        let maxEndDate = now + effectiveFutureHours * 3600

        let graphHorizon = dateTimeUtils.getTimeIntervalNHoursAgo(N: 24 * Storage.shared.downloadDays.value)

        /// Turns one kind of entry (real overrides, or Profile runs) into spans. Each entry ends
        /// at its own end or just before the next entry *of the same kind* starts.
        func spans(_ list: [(entry: [String: AnyObject], date: Date)], isWeekendProfile: Bool) -> [OverrideSpan] {
            var result: [OverrideSpan] = []
            for i in 0 ..< list.count {
                let e = list[i].entry
                let rawStart = list[i].date.timeIntervalSince1970
                let start = max(rawStart, graphHorizon)
                let nextStart: TimeInterval? = i + 1 < list.count ? list[i + 1].date.timeIntervalSince1970 : nil

                let durationSeconds = (e["duration"] as? Double ?? 5) * 60
                // Loop marks indefinite overrides explicitly; Trio represents them
                // as a ~30-day duration. Treat a week or longer as indefinite.
                let isIndefinite = (e["durationType"] as? String) == "indefinite"
                    || durationSeconds >= 7 * 24 * 3600

                var end: TimeInterval = isIndefinite ? maxEndDate : start + durationSeconds

                // True end for countdown display and the end alarm's early
                // warning: based on the raw start and never clamped to the graph
                // edge; nil while indefinite.
                var trueEnd: TimeInterval? = isIndefinite ? nil : rawStart + durationSeconds

                if let nextStart = nextStart {
                    end = min(end, nextStart - 60) // avoid overlapping overrides
                    trueEnd = trueEnd.map { min($0, nextStart - 60) }
                }

                end = min(end, maxEndDate)
                guard end > start else { continue }
                result.append(OverrideSpan(entry: e, start: start, end: end, trueEnd: trueEnd, isWeekendProfile: isWeekendProfile))
            }
            return result
        }

        let isWeekendProfileEntry: ((entry: [String: AnyObject], date: Date)) -> Bool = {
            ($0.entry["enteredBy"] as? String) == MainViewController.weekendProfileEnteredBy
        }
        let overrideSpans = spans(sorted.filter { !isWeekendProfileEntry($0) }, isWeekendProfile: false)
        let profileSpans = spans(sorted.filter(isWeekendProfileEntry), isWeekendProfile: true)

        // Trio pauses Profile while a real override runs and resumes it afterwards, but the
        // Profile entry on Nightscout keeps its original (often indefinite) duration. Cut the
        // override stretches out of each Profile span so its band picks up again once the
        // override has ended or been cancelled, instead of stopping for good at the override start.
        var profilePieces: [OverrideSpan] = []
        for profile in profileSpans {
            var pieces: [(start: TimeInterval, end: TimeInterval)] = [(profile.start, profile.end)]
            for active in overrideSpans {
                pieces = pieces.flatMap { piece -> [(start: TimeInterval, end: TimeInterval)] in
                    guard active.start < piece.end, active.end > piece.start else { return [piece] }
                    var kept: [(start: TimeInterval, end: TimeInterval)] = []
                    if active.start - 60 > piece.start { kept.append((piece.start, active.start - 60)) }
                    if active.end + 60 < piece.end { kept.append((active.end + 60, piece.end)) }
                    return kept
                }
            }
            profilePieces += pieces.map {
                OverrideSpan(entry: profile.entry, start: $0.start, end: $0.end, trueEnd: profile.trueEnd, isWeekendProfile: true)
            }
        }

        let allSpans = (overrideSpans + profilePieces)
            .filter { $0.end - $0.start >= 300 } // skip short overrides
            .sorted { $0.start < $1.start }

        for span in allSpans {
            let e = span.entry
            let dot = DataStructs.overrideStruct(
                insulNeedsScaleFactor: e["insulinNeedsScaleFactor"] as? Double ?? 1,
                date: span.start,
                endDate: span.end,
                duration: span.end - span.start,
                correctionRange: {
                    if let r = e["correctionRange"] as? [Int], r.count == 2 {
                        return r
                    }
                    let lo = e["targetBottom"] as? Int ?? 0
                    let hi = e["targetTop"] as? Int ?? 0
                    return [lo, hi]
                }(),
                enteredBy: e["enteredBy"] as? String ?? "unknown",
                // Loop stores the override name in "reason"; Trio stores it in
                // "notes". Prefer notes so Trio override names surface on the
                // graph, matching the info table and treatments list.
                reason: (e["notes"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? (e["reason"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? "",
                sgv: -20,
                scheduledEndDate: span.trueEnd
            )
            overrideGraphData.append(dot)

            // A real override wins over a Profile piece if both somehow cover "now".
            if now >= span.start, now < span.end, activeOverrideNote == nil || !span.isWeekendProfile {
                activeOverrideNote = e["notes"] as? String ?? e["reason"] as? String
                activeOverrideEndAt = span.trueEnd
                activeOverrideIsWeekendProfile = span.isWeekendProfile
            }
        }

        Observable.shared.override.value = activeOverrideNote
        Observable.shared.overrideEndAt.value = activeOverrideEndAt
        Observable.shared.weekendProfileActive.value = activeOverrideIsWeekendProfile
        if Storage.shared.device.value != "Loop" {
            if let note = activeOverrideNote {
                infoManager.updateInfoData(type: .override, value: note)
            } else {
                infoManager.clearInfoData(type: .override)
            }
        }
        if Storage.shared.graphOtherTreatments.value {
            updateOverrideGraph()
        }

        #if !targetEnvironment(macCatalyst)
            LiveActivityManager.shared.refreshFromCurrentState(reason: "overrideChanged")
        #endif
        refreshHomeScreenWidget()
    }
}
