// LoopFollow
// DynamicGlucoseColor.swift

import SwiftUI

func dynamicGlucoseColor(glucoseValue: Double, low: Double, target: Double, high: Double) -> Color {
    let redHue: CGFloat = 0.0 / 360.0
    let greenHue: CGFloat = 120.0 / 360.0
    let purpleHue: CGFloat = 270.0 / 360.0

    let hue: CGFloat
    if glucoseValue <= low {
        hue = redHue
    } else if glucoseValue >= high {
        hue = purpleHue
    } else if glucoseValue <= target {
        let ratio = CGFloat((glucoseValue - low) / (target - low))
        hue = redHue + ratio * (greenHue - redHue)
    } else {
        let ratio = CGFloat((glucoseValue - target) / (high - target))
        hue = greenHue + ratio * (purpleHue - greenHue)
    }
    return Color(hue: hue, saturation: 0.6, brightness: 0.9)
}
