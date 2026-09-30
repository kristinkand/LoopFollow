// LoopFollow
// WidgetBGStore.swift

import Foundation
#if os(iOS)
    import WidgetKit
#endif

/// One BG reading for the home screen widget graph.
struct WidgetBGPoint: Codable, Hashable {
    /// Unix epoch seconds
    let date: TimeInterval
    /// Glucose in mg/dL
    let mgdl: Double
}

/// Everything the home screen widget needs, written by the app into the
/// App Group container and read by the widget extension.
struct WidgetBGData: Codable, Equatable {
    /// Recent readings, oldest first (mg/dL).
    let points: [WidgetBGPoint]
    /// Latest reading in mg/dL.
    let latestMgdl: Double
    /// Change since previous reading in mg/dL.
    let deltaMgdl: Double
    /// Nightscout/Dexcom direction string, e.g. "Flat", "SingleUp".
    let direction: String?
    /// Time of latest reading, Unix epoch seconds.
    let readingDate: TimeInterval
    /// Display unit chosen in LoopFollow.
    let unit: GlucoseSnapshot.Unit
    /// Low / high / target lines from LoopFollow settings, in mg/dL.
    let lowMgdl: Double
    let highMgdl: Double
    let targetMgdl: Double
}

enum WidgetBGStore {
    /// Widget kind used by the home screen widget. Must match the widget definition.
    static let kind = "LoopFollowBGWidget"

    /// How much history is kept for the graph.
    static let historySeconds: TimeInterval = 6 * 60 * 60

    private static let fileName = "widget_bg_data.json"

    // MARK: - Write (app)

    /// Saves new widget data and asks WidgetKit to redraw the widget,
    /// but only when something actually changed.
    static func save(_ data: WidgetBGData) {
        if let old = load(), old == data { return }
        guard let url = fileURL(), let encoded = try? JSONEncoder().encode(data) else { return }
        do {
            try encoded.write(to: url, options: [.atomic])
            #if os(iOS)
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            #endif
        } catch {
            // Intentionally silent (extension-safe, no dependencies).
        }
    }

    // MARK: - Read (widget)

    static func load() -> WidgetBGData? {
        guard let url = fileURL(),
              FileManager.default.fileExists(atPath: url.path),
              let raw = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(WidgetBGData.self, from: raw)
    }

    // MARK: - Helpers

    private static func fileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroupID.current())?
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
