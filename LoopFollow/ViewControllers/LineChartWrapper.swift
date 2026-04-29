// LoopFollow
// LineChartWrapper.swift

import Charts
import SwiftUI

struct LineChartWrapper: UIViewRepresentable {
    let chartView: LineChartView

    func makeUIView(context _: Context) -> LineChartView {
        chartView
    }

    func updateUIView(_ uiView: LineChartView, context _: Context) {
        // The chart's data is mutated externally by MainViewController; this
        // hook ensures any SwiftUI-driven re-render still flushes the chart.
        uiView.notifyDataSetChanged()
    }
}
