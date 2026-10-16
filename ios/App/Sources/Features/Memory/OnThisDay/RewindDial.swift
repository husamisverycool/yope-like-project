// Surface: onthisday — Retro's Rewind dial (design/surfaces/onthisday.md B.6; `layout.onthisday.dial`, MERGE RM-3 / RM-4).
// Evidence: references/auto/retro/press/tc-2025-12-rewind-device-b.jpg (RAW, dial at rest: 150-pt ring, 44 slots, long /
// short ticks white 30 %, solid indicator, play glyph 35 pt), tc-2025-12-rewind-device-a.png (indicator on slot 0),
// tc-2025-12-rewind-panels.png (pause glyph while playing); APK: one tick haptic per dial step.
import DesignSystem
import SwiftUI

/// The dial: `count.onthisday.dial.ticks` slots on a ring `dimension.onthisday.dial.diameter` across, slot 0 at
/// `layout.onthisday.dial.firstSlotDegrees` clockwise from 3 o'clock, `pitchDegrees` apart; even slots long
/// (`dimension.onthisday.dial.tickLong`), odd slots short (`.tickShort`), every tick `.tickWidth` wide with rounded caps
/// (`layout.global.iconStyle`), measured inward from the outer edge, in `color.onthisday.dial.tick`. The indicator
/// (`.indicatorLength`, `color.global.textOnMedia`) is drawn on `slot` instead of its tick. In the centre, the play /
/// pause glyph (`icon.global.play` / `.pause`, ink height `dimension.onthisday.dial.glyph`) is its own button.
///
/// A circular drag anywhere on the dial steps one slot per `pitchDegrees` turned (clockwise = `onStep(+1)`, the next
/// memory; counter-clockwise = `onStep(-1)`); `onStep` returns false at the first / last memory and the turn is
/// dropped (no wrap). VoiceOver: one adjustable element (`onthisday.a11y.dial`, value "2 of 5"); play / pause is a
/// separate button. Ticks are decorative.
struct RewindDial: View {
    /// The indicator's slot (memory index mod the slot count).
    let slot: Int
    let isPlaying: Bool
    let accessibilityValue: String
    var isEnabled: Bool = true
    let onStep: (Int) -> Bool
    let onPlayPause: () -> Void
    var onDragStart: () -> Void = {}

    @State private var lastAngle: Double?
    @State private var turned: Double = 0

    private typealias Dial = Tokens.Layouts.OnthisdayDial

    var body: some View {
        let diameter = Tokens.Sizes.onthisdayDialDiameter
        ZStack {
            ring
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
                .gesture(drag(diameter: diameter), including: isEnabled ? .all : .subviews)
                .accessibilityElement()
                .accessibilityLabel(Text(Copy.onthisdayA11yDial))
                .accessibilityValue(Text(accessibilityValue))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: _ = onStep(1)
                    case .decrement: _ = onStep(-1)
                    @unknown default: break
                    }
                }
                .accessibilityIdentifier("onthisday.dial")
            playPause
        }
        .frame(width: diameter, height: diameter)
    }

    /// Ticks and the indicator.
    private var ring: some View {
        Canvas { context, size in
            let slots = max(1, Int(Dial.slots))
            let radius = min(size.width, size.height) / 2
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let width = Tokens.Sizes.onthisdayDialTickWidth
            let indicator = ((slot % slots) + slots) % slots
            for index in 0..<slots {
                let isIndicator = index == indicator
                let length: CGFloat
                if isIndicator {
                    length = Tokens.Sizes.onthisdayDialIndicatorLength
                } else {
                    length = index.isMultiple(of: 2) ? Tokens.Sizes.onthisdayDialTickLong : Tokens.Sizes.onthisdayDialTickShort
                }
                let degrees = Dial.firstSlotDegrees + CGFloat(index) * Dial.pitchDegrees
                let angle = Angle(degrees: Double(degrees)).radians
                let direction = CGPoint(x: cos(angle), y: sin(angle))
                // The ink runs from the outer edge inward; the round caps stay inside the measured length.
                let outer = radius - width / 2
                let inner = radius - length + width / 2
                var path = Path()
                path.move(to: CGPoint(x: centre.x + direction.x * outer, y: centre.y + direction.y * outer))
                path.addLine(to: CGPoint(x: centre.x + direction.x * inner, y: centre.y + direction.y * inner))
                context.stroke(
                    path,
                    with: .color(isIndicator ? Tokens.Colors.globalTextOnMedia : Tokens.Colors.onthisdayDialTick),
                    style: StrokeStyle(lineWidth: width, lineCap: .round)
                )
            }
        }
        .accessibilityHidden(true)
    }

    private var playPause: some View {
        let glyph = Tokens.Sizes.onthisdayDialGlyph
        let hit = max(glyph, Tokens.Sizes.globalMinTouchTargetIos)
        return Button(action: onPlayPause) {
            Image(systemName: isPlaying ? Tokens.Icons.globalPause : Tokens.Icons.globalPlay)
                .resizable()
                .scaledToFit()
                .frame(height: glyph)
                .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                .frame(width: hit, height: hit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(isPlaying ? Copy.onthisdayA11yPause : Copy.onthisdayA11yPlay))
        .accessibilityIdentifier("onthisday.play")
    }

    /// The angle around the dial's centre turns the dial: one step per `pitchDegrees` accumulated.
    private func drag(diameter: CGFloat) -> some Gesture {
        DragGesture(coordinateSpace: .local)
            .onChanged { value in
                let dx = Double(value.location.x - diameter / 2)
                let dy = Double(value.location.y - diameter / 2)
                let angle = Angle(radians: atan2(dy, dx)).degrees
                guard let last = lastAngle else {
                    lastAngle = angle
                    onDragStart()
                    return
                }
                var delta = angle - last
                let half = 180.0 // provenance-ok: half a turn in degrees (angle arithmetic)
                if delta > half { delta -= 2 * half }
                if delta < -half { delta += 2 * half }
                lastAngle = angle
                turned += delta
                let pitch = Double(Dial.pitchDegrees)
                while turned >= pitch {
                    if onStep(1) {
                        turned -= pitch
                    } else {
                        turned = 0
                    }
                }
                while turned <= -pitch {
                    if onStep(-1) {
                        turned += pitch
                    } else {
                        turned = 0
                    }
                }
            }
            .onEnded { _ in
                lastAngle = nil
                turned = 0
            }
    }
}
