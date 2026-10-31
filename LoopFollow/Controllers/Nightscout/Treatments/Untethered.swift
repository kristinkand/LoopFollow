// LoopFollow
// Untethered.swift

import Foundation

/// Trio's untethered watch mode: while its Apple Watch app has the pump, Trio uploads an "Untethered Watch" treatment
/// at the start, without a duration, and the same one with its duration at the end (Nightscout keeps one treatment
/// per time and type, so the end replaces the start). Shown as a band in the chart and as a row in the info table.
extension MainViewController {
    /// A start without an end older than this is a session whose end never reached Nightscout, not a running one.
    private static let untetheredOngoingLimit: TimeInterval = 24 * 3600

    func processNSUntethered(entries: [[String: AnyObject]]) {
        let now = Date().timeIntervalSince1970
        var spans: [DataStructs.untetheredStruct] = []
        for entry in entries {
            guard let dateString = entry["timestamp"] as? String ?? entry["created_at"] as? String,
                  let start = NightscoutUtils.parseDate(dateString)?.timeIntervalSince1970
            else { continue }
            if let minutes = entry["duration"] as? Double, minutes > 0 {
                spans.append(.init(date: start, endDate: start + minutes * 60, ongoing: false))
            } else if now - start < Self.untetheredOngoingLimit {
                spans.append(.init(date: start, endDate: now, ongoing: true))
            }
        }
        spans.sort { $0.date < $1.date }
        // a start whose end was lost ends where the next one begins
        for index in spans.indices.dropLast() where spans[index].ongoing {
            spans[index].endDate = spans[index + 1].date
            spans[index].ongoing = false
        }
        untetheredGraphData = spans

        if let running = spans.last, running.ongoing {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            infoManager.updateInfoData(type: .untethered, value: "since " + formatter.string(from: Date(timeIntervalSince1970: running.date)))
        } else {
            infoManager.clearInfoData(type: .untethered)
        }
        if Storage.shared.graphOtherTreatments.value {
            updateUntetheredGraph()
        }
    }

    func clearOldUntethered() {
        untetheredGraphData.removeAll()
        infoManager.clearInfoData(type: .untethered)
        updateUntetheredGraph()
    }
}
