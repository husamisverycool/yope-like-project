package app.widget

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

/**
 * The picker UI the screens pass supplies (surfaces `widget.android`, `widget.friend`, `widget.memories`,
 * `widget.styles`: choose what a widget of [WidgetKind] shows, then its style). It calls `onChosen` with the choice,
 * or `onCancel`.
 */
fun interface WidgetConfigureUi {
    @Composable fun Content(kind: WidgetKind, onChosen: (WidgetChoice) -> Unit, onCancel: () -> Unit)

    companion object {
        /** Set once at app start by the screens pass; the default draws nothing. */
        @Volatile var current: WidgetConfigureUi = WidgetConfigureUi { _, _, _ -> }
    }
}

/**
 * Widget configuration container: launched by the launcher when a widget is placed (and on
 * reconfigure), or by tapping a widget that has no group (or friend) yet. Binds the widget to the
 * choice and returns RESULT_OK; backing out returns RESULT_CANCELED, so the launcher drops the
 * widget it was placing. Which picker shows follows the widget's provider ([WidgetLayouts.kindOf]).
 */
class WidgetConfigureActivity : ComponentActivity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appWidgetId = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        setResult(RESULT_CANCELED, result())
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        val kind = WidgetLayouts.kindOf(this, appWidgetId)
        setContent { WidgetConfigureUi.current.Content(kind = kind, onChosen = { choice -> bind(choice) }, onCancel = ::finish) }
    }

    /** Binds this widget to [groupId], renders it and finishes with RESULT_OK. */
    fun bind(groupId: String) = bind(WidgetChoice(groupId = groupId))

    /** Binds this widget to [choice], renders it and finishes with RESULT_OK. */
    fun bind(choice: WidgetChoice) {
        lifecycleScope.launch {
            WidgetBinding.bind(applicationContext, appWidgetId, choice)
            setResult(RESULT_OK, result())
            finish()
        }
    }

    private fun result() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
}
