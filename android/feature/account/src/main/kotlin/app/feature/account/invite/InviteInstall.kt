package app.feature.account.invite

import android.content.Context
import android.net.Uri
import app.data.model.GroupKind
import app.feature.account.InviteLinks
import app.model.DeepLinkCodec
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/*
 * Android side of the invite install path (design/surfaces/invite.web.md → Platform notes;
 * docs/PLATFORM_CONSTRAINTS.md §4.1): the web page's "Get the app" opens the Play listing with
 * `referrer=invite_token%3D<token>`; after install the app reads `invite_token=<token>` once with
 * the Play Install Referrer API, checks the invite with the web service's
 * `/i/<token>/preview.json` before joining, and joins (`join_group`) when onboarding ends. App Links
 * to `https://<domain>/i/<token>` open the same join flow when the app is installed.
 */

/** The invite token in a Play install referrer (`invite_token=<token>`, possibly among other params). */
object InstallReferrerParser {
    const val KEY = "invite_token"

    fun inviteToken(referrer: String?): String? {
        if (referrer.isNullOrBlank()) return null
        val decoded = if (referrer.contains('%')) Uri.decode(referrer) else referrer
        val value = decoded.split('&')
            .map { it.trim() }
            .firstOrNull { it.substringBefore('=') == KEY }
            ?.substringAfter('=', "")
            ?: return null
        return value.takeIf(DeepLinkCodec::isId)
    }
}

/** Reads the Play install referrer once (InstallReferrerClient); [onResult] gets the invite token or null. */
object InstallReferrerReader {
    fun read(context: Context, onResult: (String?) -> Unit) {
        val client = try {
            InstallReferrerClient.newBuilder(context.applicationContext).build()
        } catch (_: Exception) {
            onResult(null)
            return
        }
        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    val token = if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                        try {
                            InstallReferrerParser.inviteToken(client.installReferrer.installReferrer)
                        } catch (_: Exception) {
                            null
                        }
                    } else {
                        null
                    }
                    runCatching { client.endConnection() }
                    onResult(token)
                }

                override fun onInstallReferrerServiceDisconnected() = Unit
            })
        } catch (_: Exception) {
            onResult(null)
        }
    }
}

/** What the web service says about an invite before joining (`GET /i/<token>/preview.json`). */
sealed interface InvitePreviewResult {
    data class Valid(val groupName: String, val groupKind: GroupKind?, val inviterFirstName: String?) : InvitePreviewResult

    /** HTTP 410: expired or revoked (the page does not reveal which). */
    data object Unavailable : InvitePreviewResult

    /** HTTP 404: unknown or malformed token. */
    data object NotFound : InvitePreviewResult

    /** HTTP 429. */
    data object RateLimited : InvitePreviewResult

    /** 5xx or an unexpected answer. */
    data object Error : InvitePreviewResult

    /** No connection. */
    data object Offline : InvitePreviewResult

    /** No invite domain configured (`config/app.json` `domain` BLOCKED): nothing to ask. */
    data object NotConfigured : InvitePreviewResult
}

fun interface InvitePreviewClient {
    suspend fun fetch(token: String): InvitePreviewResult
}

/** [InvitePreviewClient] over HTTPS to the invite web service on the configured domain. */
class HttpInvitePreviewClient(private val links: InviteLinks) : InvitePreviewClient {
    override suspend fun fetch(token: String): InvitePreviewResult = withContext(Dispatchers.IO) {
        val url = links.previewUrl(token) ?: return@withContext InvitePreviewResult.NotConfigured
        val connection = try {
            URL(url).openConnection() as HttpURLConnection
        } catch (_: IOException) {
            return@withContext InvitePreviewResult.Offline
        }
        try {
            connection.connectTimeout = TIMEOUT_MS
            connection.readTimeout = TIMEOUT_MS
            connection.setRequestProperty("Accept", "application/json")
            when (connection.responseCode) {
                HttpURLConnection.HTTP_OK -> parse(connection.inputStream.bufferedReader().use { it.readText() })
                HttpURLConnection.HTTP_GONE -> InvitePreviewResult.Unavailable
                HttpURLConnection.HTTP_NOT_FOUND -> InvitePreviewResult.NotFound
                TOO_MANY_REQUESTS -> InvitePreviewResult.RateLimited
                else -> InvitePreviewResult.Error
            }
        } catch (_: IOException) {
            InvitePreviewResult.Offline
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        private const val TIMEOUT_MS = 15_000
        private const val TOO_MANY_REQUESTS = 429

        /** Parses `{group_name, group_kind, inviter_first_name, cover, members, theme}`; only what joining needs is kept. */
        fun parse(body: String): InvitePreviewResult = try {
            val json: JsonObject = Json.parseToJsonElement(body).jsonObject
            val name = json["group_name"]?.jsonPrimitive?.contentOrNull ?: return InvitePreviewResult.Error
            val kind = json["group_kind"]?.jsonPrimitive?.contentOrNull?.let { wire -> GroupKind.entries.firstOrNull { it.wire == wire } }
            InvitePreviewResult.Valid(name, kind, json["inviter_first_name"]?.jsonPrimitive?.contentOrNull)
        } catch (_: Exception) {
            InvitePreviewResult.Error
        }
    }
}
