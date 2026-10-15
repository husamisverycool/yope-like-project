package app.links

import android.app.Activity
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import app.model.DeepLink
import app.model.DeepLinkCodec

/** The app's link configuration, from config/app.json via BuildConfig. */
object AppLinkConfig {
    /** Invite-link host, or null while the owner has not set `domain`. */
    val domain: String? = BuildConfig.APP_LINK_DOMAIN

    val codec: DeepLinkCodec = DeepLinkCodec(domain)
}

/** Incoming intents → [DeepLink]. Covers App Links (`https://<domain>/i/…`), widget and notification taps. */
object AppLinks {
    fun parse(intent: Intent?, codec: DeepLinkCodec = AppLinkConfig.codec): DeepLink? {
        if (intent == null || intent.action != Intent.ACTION_VIEW) return null
        return codec.parse(intent.dataString)
    }
}

/**
 * [DeepLink] → explicit [Intent] / [PendingIntent] aimed at the app's single activity. Explicit
 * intents mean the `app://` scheme needs no exported intent filter, so other apps cannot drive
 * these routes.
 */
object DeepLinkIntents {
    /** The activity that hosts navigation; set once by the app at startup. */
    @Volatile var targetActivity: Class<out Activity>? = null

    fun intent(context: Context, link: DeepLink, codec: DeepLinkCodec = AppLinkConfig.codec): Intent? {
        val uri = codec.format(link) ?: return null
        val component = targetActivity?.let { ComponentName(context, it) }
            ?: context.packageManager.getLaunchIntentForPackage(context.packageName)?.component
            ?: return null
        return Intent(Intent.ACTION_VIEW, Uri.parse(uri))
            .setComponent(component)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }

    /**
     * An immutable PendingIntent for [link]. The request code is derived from the link, so
     * different links never overwrite each other's extras.
     */
    fun pendingIntent(context: Context, link: DeepLink, codec: DeepLinkCodec = AppLinkConfig.codec): PendingIntent? {
        val intent = intent(context, link, codec) ?: return null
        return PendingIntent.getActivity(
            context,
            requestCode(link, codec),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    fun requestCode(link: DeepLink, codec: DeepLinkCodec = AppLinkConfig.codec): Int = codec.format(link).hashCode()
}
