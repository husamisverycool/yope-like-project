// Surfaces: camera.capture, camera.sendto, daily.capture, collage.share.
// Every BLOCKED value the capture screens depend on, in one place (design/BLOCKED.md). While a value
// is BLOCKED its accessor returns nil / false and the element it styles is not drawn (release and
// DEBUG: the generated `BlockedTokens` accessors trap, so they are never called). When the research
// pass unblocks a token, `node tools/designgen.mjs` moves it into `Tokens`, and the accessor below
// switches to it in one line (the line is given in each comment).
import DesignSystem
import SwiftUI

enum CaptureBlocked {
    /// `camera.sendto.color.messageField` — the message field capsule and mic circle fill.
    /// Unblocked: `Tokens.Colors.cameraSendtoColorMessageField`
    static var messageFieldFill: Color? { nil }

    /// `camera.capture.size.recordingOutline` — the accent outline around the viewfinder while a
    /// video records. Unblocked: `Tokens.Sizes.cameraCaptureSizeRecordingOutline`
    static var recordingOutlineWidth: CGFloat? { nil }

    /// `camera.sendto.duration.toastVisible` — how long the lime confirmation toast ('posted in …',
    /// 'saved to your library') stays. While nil the confirmation is announced to VoiceOver only.
    /// Unblocked: `Tokens.Durations.cameraSendtoDurationToastVisible`
    static var toastVisible: TimeInterval? { nil }

    /// `camera.sendto.size.captionMaxLength` — the caption limit (the server bound, 1000, is
    /// integrity only). Unblocked: `Int(Tokens.Counts.cameraSendtoSizeCaptionMaxLength)`
    static var captionMaxLength: Int? { nil }

    /// `daily.capture.fontWeight.countdown`. While nil the countdown keeps the platform's regular
    /// weight. Unblocked: `Tokens.FontWeights.dailyCaptureFontWeightCountdown`
    static var countdownWeight: Font.Weight? { nil }

    /// `daily.capture.color.overlayControl` — the retake circle and audience chip fill.
    /// Unblocked: `Tokens.Colors.dailyCaptureColorOverlayControl`
    static var overlayControlFill: Color? { nil }

    /// `collage.share.color.pill` — the frosted share pill fill.
    /// Unblocked: `Tokens.Colors.collageShareColorPill`
    static var sharePillFill: Color? { nil }

    /// `chat.voice.layout.recording` — the voice-note recording interaction camera.sendto reuses
    /// ("the chat.voice recorder"). Release builds leave the mic out until it is unblocked; DEBUG
    /// builds keep it (tap to start / stop) so the layout can be reviewed.
    /// Unblocked: `true`
    static var voiceNoteRecording: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
