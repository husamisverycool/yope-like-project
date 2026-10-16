package app.feature.capture.data

import android.content.Context
import androidx.core.content.edit

/** Per-install flags of the capture screens (the first-use coach pill, the session's lens). */
interface CapturePrefs {
    /** `camera.capture` coach pill "Hold to record a video": once per install (a tap or the first video ends it). */
    var holdToRecordCoachDone: Boolean

    /** The lens last used on `camera.capture` ("front after a flip, kept for the session"). */
    var frontLensThisSession: Boolean

    /**
     * `camera.overnight`: the groups 9 AM photos develop for, as last confirmed in the destination sheet ("kept for the
     * app session"); null until the sheet was confirmed once in this session (the first switch to 9 AM opens it).
     */
    var overnightGroups: Set<String>?
}

class SharedCapturePrefs(context: Context) : CapturePrefs {
    private val prefs = context.applicationContext.getSharedPreferences(NAME, Context.MODE_PRIVATE)

    override var holdToRecordCoachDone: Boolean
        get() = prefs.getBoolean(KEY_HOLD, false)
        set(value) = prefs.edit { putBoolean(KEY_HOLD, value) }

    override var frontLensThisSession: Boolean
        get() = SessionFlags.frontLens
        set(value) {
            SessionFlags.frontLens = value
        }

    override var overnightGroups: Set<String>?
        get() = SessionFlags.overnightGroups
        set(value) {
            SessionFlags.overnightGroups = value
        }

    /** Process-lifetime flags ("for the session"). */
    private object SessionFlags {
        @Volatile var frontLens: Boolean = false
        @Volatile var overnightGroups: Set<String>? = null
    }

    private companion object {
        const val NAME = "capture_ui"
        const val KEY_HOLD = "coach.holdToRecord.done"
    }
}

/** In-memory prefs (tests, previews). */
class MemoryCapturePrefs(
    override var holdToRecordCoachDone: Boolean = false,
    override var frontLensThisSession: Boolean = false,
    override var overnightGroups: Set<String>? = null,
) : CapturePrefs
