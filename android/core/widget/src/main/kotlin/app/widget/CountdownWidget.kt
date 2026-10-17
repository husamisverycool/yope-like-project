// Surface: widget.countdown — the next plan, in days (Glance, 2 × 2 and 4 × 2). Spec: design/surfaces/widget.countdown.md.
// Visual reference: Retro's Glance widget anatomy exactly as widget.home.small (full-bleed photo, layout.global.photoScrim,
// white stack at the bottom-trailing corner, system corner, white-85 % state column; references/auto/retro/apk/
// widget_preview_journals.webp). Mechanics: Apple Invites' widget ("count down the days until your next event", "In 9 Days",
// references/auto/apple-invites/store/apple-invites-store-08.png) and Widgetsmith's day-only countdown
// (references/auto/countdown-widgets/store/widgetsmith-store-05.png). Decisions: MERGE_DECISIONS PL-9 … PL-11.
package app.widget

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.icu.text.DisplayContext
import android.icu.text.RelativeDateTimeFormatter
import android.icu.util.ULocale
import android.os.Build
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.core.content.res.ResourcesCompat
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.ContentScale
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.size
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import app.designsystem.R
import app.designsystem.generated.Tokens
import app.links.DeepLinkIntents
import app.model.CountdownPlan
import app.model.CountdownSnapshot
import app.model.DeepLink
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.security.MessageDigest
import java.time.Duration
import java.time.LocalDate
import java.time.ZonedDateTime
import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * The countdown widget's files: `snapshot.json` ([CountdownSnapshot]) and the plans' covers `c-<hash>.jpg`, named by
 * the cover's storage path so an unchanged cover is never downloaded twice. Writes are atomic (temp file, flush,
 * rename); covers the snapshot no longer names are pruned after each snapshot write. Kept out of backups (per device).
 */
class CountdownStore(val root: File) {
    private val lock = Any()

    fun read(): CountdownSnapshot? {
        val file = File(root, SNAPSHOT)
        if (!file.isFile) return null
        return try {
            CountdownSnapshot.fromJson(file.readText())
        } catch (_: IOException) {
            null
        }
    }

    /** The plan's downloaded cover, or null. */
    fun cover(plan: CountdownPlan): File? = plan.coverFile?.let { safe(it) }?.let { File(root, it) }?.takeIf(File::isFile)

    fun hasCover(name: String): Boolean = File(root, safe(name)).isFile

    fun writeCover(name: String, bytes: ByteArray) = synchronized(lock) { writeAtomically(File(root, safe(name)), bytes) }

    /** Makes [snapshot] current and deletes the covers it does not name. */
    fun write(snapshot: CountdownSnapshot) = synchronized(lock) {
        writeAtomically(File(root, SNAPSHOT), snapshot.toJson().toByteArray())
        val keep = snapshot.plans.mapNotNullTo(HashSet()) { it.coverFile } + SNAPSHOT
        root.listFiles()?.filter { it.name !in keep }?.forEach { it.delete() }
    }

    /** Signed out: nothing of the last person stays on the home screen. */
    fun clear() = synchronized(lock) { root.deleteRecursively(); Unit }

    private fun writeAtomically(target: File, bytes: ByteArray) {
        root.mkdirs()
        val tmp = File(root, ".${target.name}.part")
        try {
            FileOutputStream(tmp).use { out ->
                out.write(bytes)
                out.fd.sync()
            }
            if (!tmp.renameTo(target)) {
                target.delete()
                if (!tmp.renameTo(target)) throw IOException("rename failed")
            }
        } finally {
            tmp.delete()
        }
    }

    private fun safe(name: String): String {
        require(name.isNotEmpty() && '/' !in name && '\\' !in name && !name.startsWith(".")) { "invalid file name" }
        return name
    }

    companion object {
        private const val SNAPSHOT = "snapshot.json"

        /** The file name of the cover stored at [coverPath] (`u/<uid>/covers/<uuid>.jpg`). */
        fun coverName(coverPath: String): String {
            val digest = MessageDigest.getInstance("SHA-256").digest(coverPath.toByteArray())
            return "c-" + digest.take(HASH_BYTES).joinToString("") { "%02x".format(it) } + ".jpg"
        }

        private const val HASH_BYTES = 12

        fun default(context: Context): CountdownStore = CountdownStore(File(context.noBackupFilesDir, "widgets-countdown"))
    }
}

/**
 * The countdown line (`widget.countdown` → The countdown line): day granularity from the platform formatter, never typed
 * by us — ICU `RelativeDateTimeFormatter` (style long, `DisplayContext.CAPITALIZATION_FOR_BEGINNING_OF_SENTENCE`):
 * ≥ 2 days `format(n, NEXT, DAYS)` ("In 3 days"), 1 day `format(NEXT, DAY)` ("Tomorrow"), the plan's day
 * `format(THIS, DAY)` (the same-day word, pinned by `CountdownWordsTest`). Never hours, minutes or seconds (T4).
 * [inSentence]: the same words with middle-of-sentence capitalization (`CAPITALIZATION_FOR_MIDDLE_OF_SENTENCE`), for
 * `widget.countdown.a11y.plan` ("{title} with {group}, {countdown}").
 */
object CountdownWords {
    fun text(days: Long, locale: Locale = Locale.getDefault(), inSentence: Boolean = false): String? {
        if (days < 0) return null
        val formatter = RelativeDateTimeFormatter.getInstance(
            ULocale.forLocale(locale),
            null,
            RelativeDateTimeFormatter.Style.LONG,
            if (inSentence) DisplayContext.CAPITALIZATION_FOR_MIDDLE_OF_SENTENCE else DisplayContext.CAPITALIZATION_FOR_BEGINNING_OF_SENTENCE,
        )
        return when (days) {
            0L -> formatter.format(RelativeDateTimeFormatter.Direction.THIS, RelativeDateTimeFormatter.AbsoluteUnit.DAY)
            1L -> formatter.format(RelativeDateTimeFormatter.Direction.NEXT, RelativeDateTimeFormatter.AbsoluteUnit.DAY)
            else -> formatter.format(days.toDouble(), RelativeDateTimeFormatter.Direction.NEXT, RelativeDateTimeFormatter.RelativeUnit.DAYS)
        }
    }
}

/** The device's date (the countdown counts calendar days on the viewer's calendar); replaceable in tests. */
object CountdownClock {
    @Volatile var today: () -> LocalDate = { LocalDate.now() }

    /**
     * Set by the app at process start (core:data's snapshot writer, which this module cannot depend on): asks for a snapshot
     * when the first countdown widget is placed.
     */
    @Volatile var onFirstPlaced: () -> Unit = {}
}

/**
 * The countdown widget (`widget.countdown`, Android form: Glance with the `widget.android` provider rules,
 * `SizeMode.Responsive` 2 × 2 and 4 × 2). It shows the soonest upcoming plan of all your groups ("All groups", Apple's
 * "your next event"); per-group configuration is not offered on Android yet. Tapping it opens the plan's page
 * (`DeepLink.Plan`); without a plan it opens the app.
 */
class CountdownWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(setOf(WidgetSizeClass.Small.minSize, WidgetSizeClass.Medium.minSize))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val store = CountdownStore.default(context)
        provideContent { CountdownContent(store, CountdownClock.today()) }
    }

    /**
     * The widget picker's generated preview (Android 15+, as `widget.android`'s): the next plan this device holds, else
     * the calendar glyph alone (never the signed-out or empty line); not tappable.
     */
    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        val store = CountdownStore.default(context)
        provideContent { CountdownContent(store, CountdownClock.today(), preview = true) }
    }

    companion object {
        /** Whether any countdown widget is on a home screen (the app skips the snapshot otherwise). */
        suspend fun isPlaced(context: Context): Boolean =
            GlanceAppWidgetManager(context).getGlanceIds(CountdownWidget::class.java).isNotEmpty()

        /** Re-renders every placed countdown widget and keeps the midnight refresh scheduled. */
        suspend fun refresh(context: Context) {
            CountdownWidget().updateAll(context)
            CountdownMidnight.schedule(context)
        }
    }
}

class CountdownWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = CountdownWidget()

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        CountdownMidnight.schedule(context)
        // The first widget placed: the app writes its snapshot now rather than at its next foreground.
        CountdownClock.onFirstPlaced()
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        CountdownMidnight.cancel(context)
    }

    /** The clock or the zone changed (both exempt from the implicit-broadcast limits): the day count may have changed. */
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in CLOCK_ACTIONS) CountdownMidnight.enqueueNow(context)
    }

    private companion object {
        val CLOCK_ACTIONS = setOf(Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)
    }
}

/**
 * The day count changes at local midnight only (`widget.countdown` → Motion: a new entry at midnight with the instant
 * swap of `widget.arrival.duration.transition`): one WorkManager job at the next local midnight re-renders the widgets
 * and schedules the following one; `widget.android.duration.updatePeriod` is the provider's backstop.
 */
object CountdownMidnight {
    private const val WORK = "countdown-midnight"

    fun schedule(context: Context, now: ZonedDateTime = ZonedDateTime.now()) {
        val midnight = now.toLocalDate().plusDays(1).atStartOfDay(now.zone)
        val delay = Duration.between(now, midnight).toMillis().coerceAtLeast(0)
        val request = OneTimeWorkRequestBuilder<CountdownMidnightWorker>().setInitialDelay(delay, TimeUnit.MILLISECONDS).build()
        WorkManager.getInstance(context).enqueueUniqueWork(WORK, ExistingWorkPolicy.REPLACE, request)
    }

    /** Re-render now (clock or zone changed); the job reschedules the next midnight itself. */
    fun enqueueNow(context: Context) {
        WorkManager.getInstance(context).enqueueUniqueWork(WORK, ExistingWorkPolicy.REPLACE, OneTimeWorkRequestBuilder<CountdownMidnightWorker>().build())
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK)
    }
}

class CountdownMidnightWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        if (CountdownWidget.isPlaced(applicationContext)) {
            CountdownWidget().updateAll(applicationContext)
            CountdownMidnight.schedule(applicationContext)
        }
        return Result.success()
    }
}

/** What the countdown widget shows when it has no plan to count down to. */
sealed interface CountdownEmptyState {
    /** Nothing written yet (just added, or the app has not run since): `color.global.backgroundDeep`, no content. */
    data object Loading : CountdownEmptyState

    /** No upcoming plan in any of your groups: the state column (`icon.global.calendar`, `widget.countdown.empty.noPlans`). */
    data object NoPlans : CountdownEmptyState

    /** Nobody is signed in: `widget.home.small.empty.signedOut` (shared). */
    data object SignedOut : CountdownEmptyState

    companion object {
        fun of(snapshot: CountdownSnapshot?, signedOut: Boolean): CountdownEmptyState = when {
            signedOut -> SignedOut
            snapshot == null -> Loading
            else -> NoPlans
        }
    }
}

/**
 * The widget (`widget.countdown` → Structure): the plan's cover, else the group's newest photo (the photo widget's
 * rendition when this device has one), else `color.global.backgroundDeep`; `layout.global.photoScrim`; the text stack at
 * the bottom-trailing corner (`widget.home.small.layout.overlay` insets): on 4 × 2 and up the group name
 * (`widget.home.small.fontSize.overlay`), then the title (`listTitle`), then the countdown (`displaySmall` in
 * `font.global.display`), `color.global.textOnMedia`, one line each, truncated at the leading inset
 * `size.global.screenMargin`. One TalkBack element: `widget.countdown.a11y.plan` ("{title} with {group}, {countdown}").
 */
@Composable
internal fun CountdownContent(store: CountdownStore, today: LocalDate, preview: Boolean = false) {
    val context = LocalContext.current
    val size = LocalSize.current
    val sizeClass = WidgetSizeClass.of(size)
    val signedOut = remember { WidgetGroupMeta.of(WidgetFileStore.default(context)).isSignedOut() }
    val snapshot = remember(today) { if (signedOut) null else store.read() }
    val plan = snapshot?.next(groupId = null, today = today)
    val countdown = plan?.let { CountdownWords.text(it.daysFrom(today)) }
    val density = context.resources.displayMetrics.density
    val widthPx = (size.width.value * density).roundToInt()
    val heightPx = (size.height.value * density).roundToInt()
    val photo = remember(plan, widthPx, heightPx) { plan?.let { countdownPhoto(context, store, it, widthPx, heightPx) } }

    val link = plan?.let { DeepLink.Plan(it.planId, it.groupId) }
    val intent = link?.let { DeepLinkIntents.intent(context, it) } ?: context.packageManager.getLaunchIntentForPackage(context.packageName)
    var modifier = GlanceModifier.fillMaxSize().appWidgetBackground()
    if (intent != null && !preview) modifier = modifier.clickable(actionStartActivity(intent))
    val label = when {
        plan != null && countdown != null ->
            context.getString(R.string.widget_countdown_a11y_plan, plan.title, plan.groupName, CountdownWords.text(plan.daysFrom(today), inSentence = true))
        CountdownEmptyState.of(snapshot, signedOut) == CountdownEmptyState.SignedOut -> context.getString(R.string.widget_home_small_empty_signedout)
        CountdownEmptyState.of(snapshot, signedOut) == CountdownEmptyState.NoPlans -> context.getString(R.string.widget_countdown_empty_noplans)
        else -> null
    }
    label?.let { modifier = modifier.semantics { contentDescription = it } }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) modifier = modifier.cornerRadius(Tokens.Radii.widgetAndroidRadiusWidget)

    Box(modifier = modifier) {
        if (plan == null || countdown == null) {
            if (preview) {
                TokenPhotoWidgetSlots.StateColumn(null, Tokens.Icons.globalCalendar)
                return@Box
            }
            when (CountdownEmptyState.of(snapshot, signedOut)) {
                CountdownEmptyState.Loading -> TokenPhotoWidgetSlots.StateBackground()
                CountdownEmptyState.SignedOut -> TokenPhotoWidgetSlots.StateColumn(context.getString(R.string.widget_home_small_empty_signedout), Tokens.Icons.globalCalendar)
                // "No plans yet" (`widget.countdown.empty.noPlans`, MERGE FV-2).
                CountdownEmptyState.NoPlans -> TokenPhotoWidgetSlots.StateColumn(context.getString(R.string.widget_countdown_empty_noplans), Tokens.Icons.globalCalendar)
            }
            return@Box
        }
        if (photo != null) {
            Image(ImageProvider(photo), contentDescription = null, contentScale = ContentScale.Crop, modifier = GlanceModifier.fillMaxSize())
        } else {
            TokenPhotoWidgetSlots.StateBackground()
        }
        val lines = listOfNotNull(
            plan.groupName.takeIf { sizeClass != WidgetSizeClass.Small }?.let { CountdownLine(it, CountdownLine.Role.Group) },
            CountdownLine(plan.title, CountdownLine.Role.Title),
            CountdownLine(countdown, CountdownLine.Role.Countdown),
        )
        val stack = remember(lines, widthPx) { CountdownArt.stack(context, lines, size.width) }
        if (stack != null) {
            Box(modifier = GlanceModifier.fillMaxSize(), contentAlignment = Alignment.BottomEnd) {
                Image(ImageProvider(stack.bitmap), contentDescription = null, modifier = GlanceModifier.size(stack.widthDp, stack.heightDp))
            }
        }
    }
}

/** The background: the plan's cover, else the group's newest photo on this device; cropped to the widget, scrim drawn in. */
private fun countdownPhoto(context: Context, store: CountdownStore, plan: CountdownPlan, widthPx: Int, heightPx: Int): Bitmap? {
    val photos = WidgetFileStore.default(context)
    val file = store.cover(plan) ?: runCatching { photos.read(plan.groupId)?.let(photos::photo) }.getOrNull() ?: return null
    val bitmap = WidgetBitmaps.decodeCropped(file, widthPx, heightPx) ?: return null
    return TokenPhotoWidgetSlots.photo(context, bitmap, widthPx)
}

/** One line of the countdown stack and its text role. */
internal data class CountdownLine(val text: String, val role: Role) {
    enum class Role { Group, Title, Countdown }
}

/**
 * The countdown stack drawn as one bitmap (RemoteViews cannot place baselines, set a 600 weight or use the bundled display
 * face): trailing-aligned `widget.home.small.layout.overlay` `trailingInset` from the trailing edge, the last baseline
 * `lastBaselineFromBottom` above the bottom; each line one line, ellipsized where it would pass the leading inset
 * `size.global.screenMargin`. Lines follow each other at the next line's platform line spacing (`Paint.fontSpacing`): the
 * stack mixes three sizes and no pitch between them is measured (`widget.home.small`'s 13-pt pitch is for its 11-pt lines).
 */
internal object CountdownArt {
    class Stack(val bitmap: Bitmap, val widthDp: Dp, val heightDp: Dp)

    fun stack(context: Context, lines: List<CountdownLine>, widgetWidth: Dp): Stack? {
        val density = context.resources.displayMetrics.density
        val overlay = Tokens.Layouts.WidgetHomeSmallLayoutOverlay
        val widthPx = WidgetArt.px(context, widgetWidth - Tokens.Sizes.globalScreenMargin)
        val inset = WidgetArt.px(context, Dp(overlay.trailingInset))
        val available = widthPx - inset
        if (lines.isEmpty() || available <= 0f) return null
        val rtl = context.resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL
        val color = WidgetColors.pick(context) { it.globalTextOnMedia }.toArgb()
        val paints = lines.map { line -> paint(context, line.role, color, rtl) }
        val shown = lines.mapIndexed { i, line -> TextUtils.ellipsize(line.text, paints[i], available, TextUtils.TruncateAt.END).toString() }
        val lastBaseline = WidgetArt.px(context, Dp(overlay.lastBaselineFromBottom))
        // Baseline of line i measured up from the last line's baseline.
        val rise = FloatArray(lines.size)
        for (i in lines.size - 2 downTo 0) rise[i] = rise[i + 1] + paints[i + 1].fontSpacing
        val top = -paints[0].fontMetrics.top + rise[0]
        val h = ceil(top + lastBaseline).toInt()
        val w = ceil(widthPx).toInt()
        val out = Bitmap.createBitmap(max(1, w), max(1, h), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val x = if (rtl) inset else w - inset
        shown.forEachIndexed { i, text -> canvas.drawText(text, x, h - lastBaseline - rise[i], paints[i]) }
        return Stack(out, Dp(w / density), Dp(h / density))
    }

    private fun paint(context: Context, role: CountdownLine.Role, color: Int, rtl: Boolean): TextPaint {
        val (size, weight, display) = when (role) {
            CountdownLine.Role.Group -> Triple(Tokens.FontSizes.widgetHomeSmallFontSizeOverlay, Tokens.FontWeights.widgetHomeSmallFontWeightOverlay, false)
            CountdownLine.Role.Title -> Triple(Tokens.FontSizes.globalListTitle, Tokens.FontWeights.fontWeightGlobalListTitle, false)
            CountdownLine.Role.Countdown -> Triple(Tokens.FontSizes.globalDisplaySmall, Tokens.FontWeights.fontWeightGlobalDisplaySmall, true)
        }
        return TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            textSize = WidgetArt.px(context, size)
            typeface = if (display) displayFace(context, weight) else uiFace(weight)
            textAlign = if (rtl) Paint.Align.LEFT else Paint.Align.RIGHT
        }
    }

    /** `font.global.display` (the bundled title serif, `res/font`), at the role's weight. */
    private fun displayFace(context: Context, weight: FontWeight): Typeface {
        @Suppress("DiscouragedApi") // tokens name fonts by resource name
        val name = (Tokens.Fonts.globalDisplay as? app.designsystem.DSFontFamily.Custom)?.resourceName
        val id = if (name == null) 0 else context.resources.getIdentifier(name, "font", context.packageName)
        val base = if (id != 0) runCatching { ResourcesCompat.getFont(context, id) }.getOrNull() else null
        return weighted(base ?: Typeface.SERIF, weight)
    }

    /** The widget's UI face, as the photo widget's stack (`WidgetArt`): the platform default at the role's weight. */
    private fun uiFace(weight: FontWeight): Typeface = weighted(Typeface.DEFAULT, weight)

    private fun weighted(base: Typeface, weight: FontWeight): Typeface =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) Typeface.create(base, weight.weight, false)
        else Typeface.create(base, if (weight >= FontWeight.SemiBold) Typeface.BOLD else Typeface.NORMAL)
}
