package app.feature.capture.data

import android.content.Context
import androidx.core.content.edit

/** Per-install flags of the capture screens (first-use coach tooltips). */
interface CapturePrefs {
    /** `camera.capture` coach "hold down to record": shown once per install (✕ or the first video ends it). */
    var holdToRecordCoachDone: Boolean

    /** `camera.sendto` voice coach "add a voice memo on this pic": first use only. */
    var voiceCoachDone: Boolean

    /** The lens last used on `camera.capture` ("front after a flip, kept for the session"). */
    var frontLensThisSession: Boolean
}

class SharedCapturePrefs(context: Context) : CapturePrefs {
    private val prefs = context.applicationContext.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    override var holdToRecordCoachDone: Boolean
        get() = prefs.getBoolean(KEY_HOLD, false)
        set(value) = prefs.edit { putBoolean(KEY_HOLD, value) }

    override var voiceCoachDone: Boolean
        get() = prefs.getBoolean(KEY_VOICE, false)
        set(value) = prefs.edit { putBoolean(KEY_VOICE, value) }

    override var frontLensThisSession: Boolean
        get() = SessionFlags.frontLens
        set(value) {
            SessionFlags.frontLens = value
        }

    /** Process-lifetime flags ("for the session"). */
    private object SessionFlags {
        @Volatile var frontLens: Boolean = false
    }

    private companion object {
        const val NAME = "capture_ui"
        const val KEY_HOLD = "coach.holdToRecord.done"
        const val KEY_VOICE = "coach.voice.done"
    }
}

/** In-memory prefs (tests, previews). */
class MemoryCapturePrefs(
    override var holdToRecordCoachDone: Boolean = false,
    override var voiceCoachDone: Boolean = false,
    override var frontLensThisSession: Boolean = false,
) : CapturePrefs
