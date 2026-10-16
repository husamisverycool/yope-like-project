// Surface: daily.capture (title slot: countdown, then the group name) — visual reference Retro (C-29 title slot, text
// role `sheetTitle`), mechanics BeReal (MM:SS countdown of the window).
// Reference images: references/auto/retro/store/retro-store-03.png (ST-03: centred sheet title on the black composer),
// references/auto/bereal/frames/appstore-preview-2026_t3.50s_capture.png (MM:SS) (design/surfaces/daily.capture.md;
// RC-12, RC-13; SPEC_FLAGS T4).
import AppModels
import DesignSystem
import SwiftUI

/// The daily capture's title slot: while the window is open the countdown `daily.capture.countdown` (MM:SS, text role
/// `sheetTitle`, monospaced digits, `color.global.textOnMedia`) — changed digits cross-fade over
/// `duration.global.crossfade` and nothing shifts; at `closes_at` (or when opened late) it cross-fades to the group name in
/// the same role. Nothing changes colour or says "late" (tenet 5). Accessibility: the countdown is a header whose value is
/// the platform's spoken duration, updated without announcements.
struct DailyCaptureTitle: View {
    let closesAt: Date?
    let opensAt: Date?
    let clock: ServerClock
    let groupName: String

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in // provenance-ok: one tick per second (MM:SS countdown)
            let seconds = remainingSeconds(at: context.date)
            ZStack {
                if let seconds {
                    CountdownDigits(text: CaptureFormat.countdown(remainingSeconds: seconds))
                        .accessibilityElement(children: .ignore)
                        .accessibilityValue(Text(CaptureFormat.spokenCountdown(remainingSeconds: seconds)))
                        .accessibilityAddTraits([.isHeader, .updatesFrequently])
                        .accessibilityIdentifier("daily.capture.countdown")
                        .dsTransition(.opacity)
                } else {
                    Text(groupName)
                        .dsTextRole(TextRole.sheetTitle)
                        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("daily.capture.groupName")
                        .dsTransition(.opacity)
                }
            }
            .dsAnimation(ComponentMotion.crossfade, value: seconds == nil)
        }
    }

    /// Remaining whole seconds while the window is open; nil otherwise (no 'late' state).
    func remainingSeconds(at date: Date) -> Int? {
        guard let closesAt else { return nil }
        return CountdownState(opensAt: opensAt, closesAt: closesAt, now: date, clock: clock).remainingWholeSeconds
    }
}

/// MM:SS where only the changed digits cross-fade (`duration.global.crossfade`; the same under Reduce Motion — RC-13: no
/// BeReal digit roll). Monospaced digits, so the colon never moves.
struct CountdownDigits: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, character in
                ZStack {
                    Text(String(character))
                        .id(character)
                        .transition(.opacity)
                }
            }
        }
        .dsTextRole(TextRole.sheetTitle)
        .monospacedDigit()
        .foregroundStyle(Tokens.Colors.globalTextOnMedia)
        .dsAnimation(ComponentMotion.crossfade, value: text)
    }
}
