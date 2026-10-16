// Shared component — C-36 Voice waveform (design/components.md; owner decision 16). Tokens `layout.global.waveform`,
// `size.global.waveformBarWidth` / `.waveformBarGap` / `.waveformBarMinHeight`. Evidence:
// references/auto/imessage/apple-support/messages-audio-message-ios27.png (38 bars, 2.02 / 2.07 pt),
// references/auto/whatsapp/store/whatsapp-store-02.png (silent bars are dots, idle all unplayed),
// references/auto/whatsapp/blog/whatsapp-blog-2022-03-voice-updates.png (bars up to 0.553 of the capsule; played /
// unplayed); measurements design/research/voice-waveform.md.
import AppModels
import DesignSystem
import SwiftUI

/// A row of capsule-ended bars centred on the row's middle: the bar count follows the width (each bar the peak of its
/// bucket of levels), heights run from `size.global.waveformBarMinHeight` (a dot) to `maxHeightRatio` × the holder's
/// height, scaled to the note's largest level. Idle (`progress` nil): every bar unplayed (`color.global.textSecondary`);
/// playing or paused part-way: bars left of the progress edge played (`color.global.textPrimary`, media
/// `color.global.textOnMedia`), the bar under the edge split. No levels (an older note): every bar a dot.
/// Decorative for VoiceOver: the holder reads the note.
struct VoiceWaveform: View {
    /// The note's stored levels (0…31); nil → the dots fallback.
    let levels: [Int]?
    /// 0…1 of the note while it plays or is paused part-way; nil when idle.
    var progress: Double?
    /// On a media surface (viewer, send-to): played bars in `color.global.textOnMedia`.
    var onMedia = false
    /// The height of the capsule or field that holds the waveform.
    let holderHeight: CGFloat

    var body: some View {
        let maxHeight = holderHeight * Tokens.Layouts.GlobalWaveform.maxHeightRatio
        let levels = self.levels
        let progress = self.progress
        let played = onMedia ? Tokens.Colors.globalTextOnMedia : Tokens.Colors.globalTextPrimary
        let unplayed = Tokens.Colors.globalTextSecondary
        Canvas { context, size in
            let barWidth = Tokens.Sizes.globalWaveformBarWidth
            let bars = WaveformBars(
                levels: levels,
                width: size.width,
                barWidth: barWidth,
                gap: Tokens.Sizes.globalWaveformBarGap,
                minHeight: Tokens.Sizes.globalWaveformBarMinHeight,
                maxHeight: maxHeight
            )
            for (index, height) in bars.heights.enumerated() {
                let rect = CGRect(x: bars.x(of: index), y: (size.height - height) / 2, width: barWidth, height: height)
                let bar = Path(roundedRect: rect, cornerRadius: barWidth / 2)
                let share = progress.map { bars.playedShare(of: index, progress: $0) } ?? 0
                if share >= 1 {
                    context.fill(bar, with: .color(played))
                } else {
                    context.fill(bar, with: .color(unplayed))
                    if share > 0 {
                        var edge = context
                        edge.clip(to: Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width * share, height: rect.height)))
                        edge.fill(bar, with: .color(played))
                    }
                }
            }
        }
        .frame(height: maxHeight)
        .accessibilityHidden(true)
    }
}
