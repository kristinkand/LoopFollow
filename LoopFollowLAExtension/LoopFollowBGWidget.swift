// LoopFollow
// LoopFollowBGWidget.swift

import Charts
import SwiftUI
import WidgetKit

// MARK: - Widget

struct LoopFollowBGWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetBGStore.kind, provider: BGWidgetProvider()) { entry in
            BGWidgetView(entry: entry)
        }
        .configurationDisplayName("Blood Glucose")
        .description("Current BG, trend arrow and graph.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Timeline

struct BGWidgetEntry: TimelineEntry {
    let date: Date
    let data: WidgetBGData?
}

struct BGWidgetProvider: TimelineProvider {
    func placeholder(in _: Context) -> BGWidgetEntry {
        BGWidgetEntry(date: Date(), data: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (BGWidgetEntry) -> Void) {
        let data = WidgetBGStore.load() ?? (context.isPreview ? .sample : nil)
        completion(BGWidgetEntry(date: Date(), data: data))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<BGWidgetEntry>) -> Void) {
        let data = WidgetBGStore.load()
        let now = Date()
        // One entry per minute so "x min" and the stale look stay correct between
        // app updates. Timeline entries do not use WidgetKit's refresh budget.
        let entries = (0 ..< 30).map { i in
            BGWidgetEntry(date: now.addingTimeInterval(Double(i) * 60), data: data)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Root view

struct BGWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BGWidgetEntry

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if family == .accessoryRectangular {
                    Color.clear
                } else {
                    Color(uiColor: .systemBackground)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let data = entry.data {
            switch family {
            case .systemMedium:
                MediumBGView(data: data, now: entry.date)
            case .accessoryRectangular:
                RectangularBGView(data: data, now: entry.date)
            default:
                SmallBGView(data: data, now: entry.date)
            }
        } else {
            Text("Open LoopFollow to load BG")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Family layouts

private struct SmallBGView: View {
    let data: WidgetBGData
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            BGHeader(data: data, now: now, size: 34)
            HStack {
                Text(BGWidgetFormat.delta(data))
                Spacer()
                Text(BGWidgetFormat.ago(data, now: now))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            BGGraph(data: data, now: now, window: 3 * 3600, showTimeAxis: false, lineWidth: 2.5)
        }
    }
}

private struct MediumBGView: View {
    let data: WidgetBGData
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                BGHeader(data: data, now: now, size: 44)
                Text("\(BGWidgetFormat.delta(data)) \(data.unit.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(BGWidgetFormat.ago(data, now: now))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 115, alignment: .leading)
            BGGraph(data: data, now: now, window: 4 * 3600, showTimeAxis: true, lineWidth: 3)
        }
    }
}

private struct RectangularBGView: View {
    let data: WidgetBGData
    let now: Date

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                BGHeader(data: data, now: now, size: 24)
                Text(BGWidgetFormat.ago(data, now: now))
                    .font(.caption2)
            }
            BGGraph(data: data, now: now, window: 2 * 3600, showTimeAxis: false, lineWidth: 2, monochrome: true)
        }
    }
}

// MARK: - Building blocks

/// Big BG value followed by the trend arrow.
private struct BGHeader: View {
    let data: WidgetBGData
    let now: Date
    let size: CGFloat

    var body: some View {
        let stale = BGWidgetFormat.isStale(data, now: now)
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(BGWidgetFormat.value(data.latestMgdl, unit: data.unit))
                .font(.system(size: size, weight: .bold, design: .rounded))
                .strikethrough(stale)
            Text(BGWidgetFormat.arrow(data.direction))
                .font(.system(size: size * 0.6, weight: .semibold))
        }
        .foregroundStyle(stale ? Color.secondary : BGWidgetColors.range(data.latestMgdl, data: data))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// BG line for the chosen time window, colored with the same Trio-style
/// gradient as the main graph and Live Activity, plus dashed low/high lines.
private struct BGGraph: View {
    let data: WidgetBGData
    let now: Date
    let window: TimeInterval
    let showTimeAxis: Bool
    let lineWidth: CGFloat
    var monochrome = false

    /// A line piece between two readings, colored by the earlier reading
    /// (same rule as the main graph).
    private struct Segment: Identifiable {
        let id: Int
        let from: WidgetBGPoint
        let to: WidgetBGPoint
    }

    var body: some View {
        let start = now.addingTimeInterval(-window)
        let visible = data.points.filter { $0.date >= start.timeIntervalSince1970 }
        let values = visible.map(\.mgdl)
        let yMin = min(values.min() ?? data.lowMgdl, data.lowMgdl) - 10
        let yMax = max(values.max() ?? data.highMgdl, data.highMgdl) + 10
        let lineColor = Color.gray.opacity(0.6)
        let segments = makeSegments(visible)

        Chart {
            RuleMark(y: .value("Low", display(data.lowMgdl)))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(lineColor)
            RuleMark(y: .value("High", display(data.highMgdl)))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .foregroundStyle(lineColor)
            ForEach(segments) { seg in
                LineMark(
                    x: .value("Time", Date(timeIntervalSince1970: seg.from.date)),
                    y: .value("BG", display(seg.from.mgdl)),
                    series: .value("Segment", seg.id)
                )
                .foregroundStyle(color(seg.from.mgdl))
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                LineMark(
                    x: .value("Time", Date(timeIntervalSince1970: seg.to.date)),
                    y: .value("BG", display(seg.to.mgdl)),
                    series: .value("Segment", seg.id)
                )
                .foregroundStyle(color(seg.from.mgdl))
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            // Mark the latest reading with a dot.
            if let last = visible.last {
                PointMark(
                    x: .value("Time", Date(timeIntervalSince1970: last.date)),
                    y: .value("BG", display(last.mgdl))
                )
                .symbolSize(lineWidth * 12)
                .foregroundStyle(color(last.mgdl))
            }
        }
        .chartXScale(domain: start ... now)
        .chartYScale(domain: display(yMin) ... display(yMax))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { _ in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.25))
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartXAxis(showTimeAxis ? .visible : .hidden)
    }

    /// Joins neighbouring readings, leaving a gap where readings are missing (> 15 min).
    private func makeSegments(_ points: [WidgetBGPoint]) -> [Segment] {
        guard points.count > 1 else { return [] }
        var result: [Segment] = []
        for i in 1 ..< points.count {
            let a = points[i - 1]
            let b = points[i]
            if b.date - a.date <= 15 * 60 {
                result.append(Segment(id: i, from: a, to: b))
            }
        }
        return result
    }

    private func color(_ mgdl: Double) -> Color {
        monochrome ? Color.primary : BGWidgetColors.range(mgdl, data: data)
    }

    private func display(_ mgdl: Double) -> Double {
        data.unit == .mmol ? GlucoseConversion.toMmol(mgdl) : mgdl
    }
}

// MARK: - Formatting & colors

private enum BGWidgetFormat {
    static let staleAfterMinutes = 15

    static func minutesAgo(_ data: WidgetBGData, now: Date) -> Int {
        max(0, Int((now.timeIntervalSince1970 - data.readingDate) / 60))
    }

    static func isStale(_ data: WidgetBGData, now: Date) -> Bool {
        minutesAgo(data, now: now) >= staleAfterMinutes
    }

    static func ago(_ data: WidgetBGData, now: Date) -> String {
        let m = minutesAgo(data, now: now)
        return m == 0 ? "now" : "\(m) min"
    }

    static func value(_ mgdl: Double, unit: GlucoseSnapshot.Unit) -> String {
        switch unit {
        case .mgdl:
            return "\(Int(mgdl.rounded()))"
        case .mmol:
            return String(format: "%.1f", GlucoseConversion.toMmol(mgdl))
        }
    }

    static func delta(_ data: WidgetBGData) -> String {
        switch data.unit {
        case .mgdl:
            let v = Int(data.deltaMgdl.rounded())
            return v > 0 ? "+\(v)" : "\(v)"
        case .mmol:
            let v = GlucoseConversion.toMmol(data.deltaMgdl)
            if abs(v) < 0.05 { return "0.0" }
            return v > 0 ? String(format: "+%.1f", v) : String(format: "%.1f", v)
        }
    }

    static func arrow(_ direction: String?) -> String {
        switch direction {
        case "DoubleUp", "TripleUp": return "↑↑"
        case "SingleUp": return "↑"
        case "FortyFiveUp": return "↗"
        case "Flat": return "→"
        case "FortyFiveDown": return "↘"
        case "SingleDown": return "↓"
        case "DoubleDown", "TripleDown": return "↓↓"
        default: return ""
        }
    }
}

private enum BGWidgetColors {
    /// Trio-style gradient: red at low, green at target, purple at high.
    /// Uses the shared `dynamicGlucoseColor` so the widget matches the app and Live Activity.
    static func range(_ mgdl: Double, data: WidgetBGData) -> Color {
        dynamicGlucoseColor(
            glucoseValue: mgdl,
            low: data.lowMgdl,
            target: data.targetMgdl,
            high: data.highMgdl
        )
    }
}

// MARK: - Sample data (widget gallery preview)

extension WidgetBGData {
    static var sample: WidgetBGData {
        let now = Date().timeIntervalSince1970
        let points = (0 ..< 72).map { i in
            WidgetBGPoint(date: now - Double(71 - i) * 300, mgdl: 130 + 55 * sin(Double(i) / 9))
        }
        return WidgetBGData(
            points: points,
            latestMgdl: points.last?.mgdl ?? 120,
            deltaMgdl: 3,
            direction: "Flat",
            readingDate: now,
            unit: .mgdl,
            lowMgdl: 70,
            highMgdl: 180,
            targetMgdl: 100
        )
    }
}
