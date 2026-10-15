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
 * The picker UI the screens pass supplies (surface `widget.android`: choose the group a widget
 * shows). It calls [onGroupChosen] with a group id, or [onCancel].
 */
fun interface WidgetConfigureUi {
    @Composable fun Content(onGroupChosen: (groupId: String) -> Unit, onCancel: () -> Unit)

    companion object {
        /** Set once at app start by the screens pass; the default draws nothing. */
        @Volatile var current: WidgetConfigureUi = WidgetConfigureUi { _, _ -> }
    }
}

/**
 * Widget configuration container: launched by the launcher when a widget is placed (and on
 * reconfigure), or by tapping a widget that has no group yet. Binds the widget to the chosen
 * group and returns RESULT_OK; backing out returns RESULT_CANCELED, so the launcher drops the
 * widget it was placing.
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
        setContent { WidgetConfigureUi.current.Content(onGroupChosen = ::bind, onCancel = ::finish) }
    }

    /** Binds this widget to [groupId], renders it and finishes with RESULT_OK. */
    fun bind(groupId: String) {
        lifecycleScope.launch {
            WidgetBinding.bind(applicationContext, appWidgetId, groupId)
            setResult(RESULT_OK, result())
            finish()
        }
    }

    private fun result() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
}
