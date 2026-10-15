// Surface: daily.capture (countdown) — reference app: BeReal.
// Reference images: references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png,
// appstore-preview-2026_timer-roll_f086-f129.png, tiktok-bereal-7339559678604627233_timer-roll_f496-f529.png
// (design/surfaces/daily.capture.md). MM:SS, shown only while the window is open (SPEC_FLAGS T4).
import AppModels
import DesignSystem
import SwiftUI

/// The invitation countdown: ticks every `daily.capture.layout.countdownTick.tick`; only the
/// changed digits move; the colon never moves; it leaves at `closes_at` and nothing takes its place.
struct DailyCountdownView: View {
    let closesAt: Date?
    let opensAt: Date?
    let clock: ServerClock

    private typealias Tick = Tokens.Layouts.DailyCaptureLayoutCountdownTick

    var body: some View {
        TimelineView(.periodic(from: .now, by: Double(Tick.tick) / 1000)) { context in
            let seconds = remainingSeconds(at: context.date)
            ZStack {
                if let seconds {
                    CountdownDigits(text: CaptureFormat.countdown(remainingSeconds: seconds))
                        .accessibilityElement(children: .ignore)
                        .accessibilityValue(CaptureFormat.spokenCountdown(remainingSeconds: seconds))
                        .accessibilityIdentifier("daily.capture.countdown")
                        .transition(.opacity.animation(DSAnimation.measured(milliseconds: Tick.digitOut).animation))
                }
            }
        }
    }

    /// Remaining whole seconds while the window is open; nil otherwise (no 'late' state).
    func remainingSeconds(at date: Date) -> Int? {
        guard let closesAt else { return nil }
        return CountdownState(opensAt: opensAt, closesAt: closesAt, now: date, clock: clock).remainingWholeSeconds
    }
}

/// Digits that roll individually: the old digit slides up `travel` and fades out (digitOut); the
/// new one rises from `travel` below (digitIn) and fades in (digitFadeIn). Reduce Motion: the
/// changed digits cross-fade over digitOut / digitIn, no movement.
struct CountdownDigits: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias Tick = Tokens.Layouts.DailyCaptureLayoutCountdownTick

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                ZStack {
                    if character.isNumber {
                        Text(String(character))
                            .id(character)
                            .transition(transition)
                    } else {
                        Text(String(character))
                    }
                }
            }
        }
        .dsTextStyle(CaptureType.countdown)
        .monospacedDigit()
        .foregroundStyle(Tokens.Colors.dailyCaptureColorText)
    }

    private var transition: AnyTransition {
        let digitOut = DSAnimation.measured(milliseconds: Tick.digitOut).resolved(reduceMotion: reduceMotion)
        let digitIn = DSAnimation.measured(milliseconds: Tick.digitIn).resolved(reduceMotion: reduceMotion)
        let fadeIn = DSAnimation.measured(milliseconds: Tick.digitFadeIn).resolved(reduceMotion: reduceMotion)
        if reduceMotion {
            return .asymmetric(insertion: .opacity.animation(digitIn), removal: .opacity.animation(digitOut))
        }
        let insertion = AnyTransition.offset(y: Tick.travel).animation(digitIn)
            .combined(with: AnyTransition.opacity.animation(fadeIn))
        let removal = AnyTransition.offset(y: -Tick.travel).combined(with: .opacity).animation(digitOut)
        return .asymmetric(insertion: insertion, removal: removal)
    }
}
