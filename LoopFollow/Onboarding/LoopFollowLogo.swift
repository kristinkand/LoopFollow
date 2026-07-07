// LoopFollow
// LoopFollowLogo.swift

import SwiftUI

/// The LoopFollow mark, rebuilt in SwiftUI as the full app-icon face — a glassy
/// rounded square with the blue "loop" ring — so it has real visual mass when
/// tilted in 3D (a bare ring collapses to a line edge-on).
struct LoopFollowLogo: View {
    var size: CGFloat = 120

    // Colors sampled from the app icon (loopfollow-icon.svg).
    private let lightBlue = Color(red: 0.357, green: 0.639, blue: 0.961) // #5BA3F5
    private let midBlue = Color(red: 0.290, green: 0.565, blue: 0.886) // #4A90E2
    private let darkBlue = Color(red: 0.227, green: 0.482, blue: 0.784) // #3A7BC8

    var body: some View {
        let corner = size * 0.225
        let ringInset = size * 0.20
        let ringWidth = size * 0.17

        ZStack {
            // Glassy white card (the icon face).
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.99), Color.white, Color(white: 0.93)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Soft sheen across the top half.
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.75), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // Blue glass ring.
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [lightBlue, midBlue, darkBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: ringWidth
                )
                .padding(ringInset)

            // Inner shadow on the ring for depth.
            Circle()
                .stroke(Color.black.opacity(0.16), lineWidth: ringWidth * 0.2)
                .blur(radius: ringWidth * 0.12)
                .padding(ringInset)
                .mask(Circle().stroke(lineWidth: ringWidth).padding(ringInset))

            // Specular highlight on the upper-left of the ring.
            Circle()
                .trim(from: 0.55, to: 0.80)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.9), Color.white.opacity(0.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringWidth * 0.42, lineCap: .round)
                )
                .blur(radius: ringWidth * 0.08)
                .padding(ringInset)
        }
        .frame(width: size, height: size)
    }
}

/// LoopFollow logo that lands like a coin: it starts edge-on (rotated 90° about
/// the vertical axis) and springs open to face the viewer, overshooting a little
/// past flat and rocking back to rest. Respects Reduce Motion by rendering flat.
struct AnimatedLoopFollowLogo: View {
    var size: CGFloat = 140

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var angle: Double = 90

    var body: some View {
        LoopFollowLogo(size: size)
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            // Grounding shadow so the landing reads as dimensional.
            .shadow(color: .black.opacity(0.28), radius: size * 0.08, x: 0, y: size * 0.06)
            .onAppear {
                if reduceMotion {
                    angle = 0
                } else {
                    withAnimation(.spring(response: 0.85, dampingFraction: 0.5).delay(0.15)) {
                        angle = 0
                    }
                }
            }
    }
}
