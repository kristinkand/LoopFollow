// LoopFollow
// AppIconComplication.swift

import SwiftUI
import UIKit
import WidgetKit

/// The app icon picked on the phone, as a watch face complication that opens
/// LoopFollow. watchOS has no alternate app icons, so this is how the watch
/// follows the phone's icon picker.
struct AppIconComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AppIconComplication", provider: AppIconTimelineProvider()) { entry in
            AppIconComplicationView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("LoopFollow Icon")
        .description("The app icon picked in LoopFollow on your iPhone. Tap to open LoopFollow.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

struct AppIconEntry: TimelineEntry {
    let date: Date
    let iconName: String
}

/// The icon only changes when the phone sends a new choice, which reloads all
/// timelines, so a single entry is enough.
struct AppIconTimelineProvider: TimelineProvider {
    private static var current: AppIconEntry {
        AppIconEntry(date: Date(), iconName: WatchStateStore.load()?.appIcon ?? "Classic")
    }

    func placeholder(in _: Context) -> AppIconEntry {
        AppIconEntry(date: Date(), iconName: "Classic")
    }

    func getSnapshot(in _: Context, completion: @escaping (AppIconEntry) -> Void) {
        completion(Self.current)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<AppIconEntry>) -> Void) {
        completion(Timeline(entries: [Self.current], policy: .never))
    }
}

struct AppIconComplicationView: View {
    let entry: AppIconEntry
    @Environment(\.widgetFamily) private var family

    /// Falls back to the classic icon for a name this build doesn't have.
    private var imageName: String {
        let name = "WatchIcon-\(entry.iconName)"
        return UIImage(named: name) != nil ? name : "WatchIcon-Classic"
    }

    var body: some View {
        switch family {
        case .accessoryCorner:
            icon
                .padding(4)
                .widgetLabel { Text("LoopFollow") }
        default:
            icon
        }
    }

    @ViewBuilder
    private var icon: some View {
        if #available(watchOS 11.0, *) {
            Image(imageName)
                .resizable()
                .widgetAccentedRenderingMode(.fullColor)
                .scaledToFill()
                .clipShape(Circle())
        } else {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        }
    }
}
