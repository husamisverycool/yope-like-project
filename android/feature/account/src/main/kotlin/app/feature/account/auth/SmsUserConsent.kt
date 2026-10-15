package app.feature.account.auth

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status

/** Finds the verification code in an SMS: the first run of 4–10 digits (`auth.code.layout.codeField` android). */
object SmsCode {
    private val CODE = Regex("(?<![0-9])[0-9]{4,10}(?![0-9])")

    fun extract(message: String?): String? = message?.let { CODE.find(it)?.value }
}

/**
 * The SMS User Consent API (`auth.code.layout.codeField` android; docs/PLATFORM_CONSTRAINTS.md §7):
 * `SmsRetriever.getClient(context).startSmsUserConsent(null)` when the screen appears; when the code
 * SMS arrives the system consent sheet (system UI) asks the person; on Allow the code goes to
 * [onCode]. Listens for 5 minutes per start (the API's own window). Missing Play services: nothing
 * happens (the field still offers `ContentType.SmsOtpCode` autofill).
 */
@Composable
fun SmsUserConsentEffect(enabled: Boolean, restartKey: Any?, onCode: (String) -> Unit) {
    val context = LocalContext.current
    val deliver by rememberUpdatedState(onCode)
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            SmsCode.extract(result.data?.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE))?.let(deliver)
        }
    }
    DisposableEffect(enabled, restartKey) {
        if (!enabled) return@DisposableEffect onDispose { }
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context, intent: Intent) {
                if (intent.action != SmsRetriever.SMS_RETRIEVED_ACTION) return
                val extras = intent.extras ?: return
                @Suppress("DEPRECATION")
                val status = extras.get(SmsRetriever.EXTRA_STATUS) as? Status ?: return
                if (status.statusCode != CommonStatusCodes.SUCCESS) return
                val consent: Intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    extras.getParcelable(SmsRetriever.EXTRA_CONSENT_INTENT, Intent::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    extras.getParcelable(SmsRetriever.EXTRA_CONSENT_INTENT)
                } ?: return
                // Only launch the Play services consent activity, without URI grants (Google's guidance).
                val target = consent.resolveActivity(c.packageManager)
                val grants = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                if (target?.packageName == PLAY_SERVICES && consent.flags and grants == 0) {
                    runCatching { launcher.launch(consent) }
                }
            }
        }
        val registered = try {
            SmsRetriever.getClient(context).startSmsUserConsent(null)
            ContextCompat.registerReceiver(
                context,
                receiver,
                IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION),
                SmsRetriever.SEND_PERMISSION,
                null,
                ContextCompat.RECEIVER_EXPORTED,
            )
            true
        } catch (_: Exception) {
            false
        }
        onDispose { if (registered) runCatching { context.unregisterReceiver(receiver) } }
    }
}

private const val PLAY_SERVICES = "com.google.android.gms"
