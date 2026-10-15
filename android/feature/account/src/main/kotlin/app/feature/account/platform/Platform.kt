package app.feature.account.platform

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract
import androidx.browser.customtabs.CustomTabsIntent
import app.data.auth.KeystoreSessionCipher
import app.media.EncodeOptions
import app.media.PhotoImport
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

/** What the account flows keep on this device (not on the server). */
interface AccountStores {
    /** An invite to join once onboarding ends (App Link or Play install referrer). */
    var pendingInviteToken: String?

    /** Whether the Play install referrer was already read (it is read once, after install). */
    var referrerChecked: Boolean

    /** Onboarding (notifications + widget steps) finished for [userId] on this device. */
    fun isOnboardingDone(userId: String): Boolean
    fun setOnboardingDone(userId: String)

    /**
     * The under-minimum-age refusal (`auth.agegate` "under age"): remembered so the screen cannot be
     * retried by going back. Holds the minimum age shown in the refusal title.
     */
    fun ageRefusal(): AgeRefusal?
    fun rememberAgeRefusal(refusal: AgeRefusal)
}

data class AgeRefusal(val minAge: Int?)

/**
 * [AccountStores] in app-private preferences; the age refusal is a file encrypted with an Android
 * Keystore key (`KeystoreSessionCipher`, core:data), per `auth.agegate` ("Keystore-backed preference").
 */
class DeviceAccountStores(context: Context) : AccountStores {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val refusalFile = File(context.applicationContext.noBackupFilesDir, REFUSAL_FILE)
    private val cipher by lazy { KeystoreSessionCipher(REFUSAL_ALIAS) }

    override var pendingInviteToken: String?
        get() = prefs.getString(KEY_INVITE, null)
        set(value) = prefs.edit().apply { if (value == null) remove(KEY_INVITE) else putString(KEY_INVITE, value) }.apply()

    override var referrerChecked: Boolean
        get() = prefs.getBoolean(KEY_REFERRER, false)
        set(value) = prefs.edit().putBoolean(KEY_REFERRER, value).apply()

    override fun isOnboardingDone(userId: String): Boolean = prefs.getBoolean(KEY_ONBOARDED + userId, false)
    override fun setOnboardingDone(userId: String) = prefs.edit().putBoolean(KEY_ONBOARDED + userId, true).apply()

    override fun ageRefusal(): AgeRefusal? {
        if (!refusalFile.isFile) return null
        return try {
            val plain = String(cipher.decrypt(refusalFile.readBytes()), Charsets.UTF_8)
            AgeRefusal(plain.removePrefix(REFUSED).toIntOrNull())
        } catch (_: Exception) {
            // A file that does not decrypt was still written by a refusal: keep refusing.
            AgeRefusal(null)
        }
    }

    override fun rememberAgeRefusal(refusal: AgeRefusal) {
        val bytes = (REFUSED + (refusal.minAge?.toString() ?: "")).toByteArray(Charsets.UTF_8)
        val blob = try {
            cipher.encrypt(bytes)
        } catch (_: Exception) {
            bytes
        }
        refusalFile.parentFile?.mkdirs()
        refusalFile.writeBytes(blob)
    }

    private companion object {
        const val PREFS = "account"
        const val KEY_INVITE = "pending_invite"
        const val KEY_REFERRER = "referrer_checked"
        const val KEY_ONBOARDED = "onboarded_"
        const val REFUSAL_FILE = "age_gate.bin"
        const val REFUSAL_ALIAS = "age_gate_refusal"
        const val REFUSED = "refused:"
    }
}

/** A contact with a phone number (groups.invite contact rows). */
data class DeviceContact(val id: String, val name: String, val phone: String, val photo: Uri?)

interface ContactsSource {
    /** Contacts with a phone number, by name; empty without `READ_CONTACTS`. */
    suspend fun contacts(): List<DeviceContact>
}

/** Reads `ContactsContract` (only after `READ_CONTACTS` is granted; groups.invite contacts section). */
class DeviceContactsSource(private val context: Context) : ContactsSource {
    override suspend fun contacts(): List<DeviceContact> = withContext(Dispatchers.IO) {
        val out = LinkedHashMap<String, DeviceContact>()
        try {
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.PHOTO_THUMBNAIL_URI,
                ),
                null,
                null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " COLLATE LOCALIZED ASC",
            )?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getString(0) ?: continue
                    val name = c.getString(1)?.takeIf { it.isNotBlank() } ?: continue
                    val phone = c.getString(2)?.takeIf { it.isNotBlank() } ?: continue
                    out.putIfAbsent(id, DeviceContact(id, name, phone, c.getString(3)?.let(Uri::parse)))
                }
            }
        } catch (_: SecurityException) {
        }
        out.values.toList()
    }
}

/** Turns a picked image (system photo picker) into an upload-ready JPEG. */
fun interface ImageImporter {
    suspend fun importJpeg(uri: Uri): File
}

/**
 * Photo Picker result → JPEG (EXIF orientation applied, no metadata) in the cache directory, at the
 * worker's display rendition limit and JPEG quality (backend/worker/src/media/renditions.ts: long
 * edge 2796 px = 932 pt × 3, quality 85).
 */
class DeviceImageImporter(private val context: Context) : ImageImporter {
    override suspend fun importJpeg(uri: Uri): File = withContext(Dispatchers.IO) {
        val out = File(context.cacheDir, "picked/${UUID.randomUUID()}.jpg")
        PhotoImport.import(context, uri, out, EncodeOptions(maxLongEdgePx = DISPLAY_LONG_EDGE_PX, jpegQuality = JPEG_QUALITY)).file
    }

    private companion object {
        const val DISPLAY_LONG_EDGE_PX = 2796
        const val JPEG_QUALITY = 85
    }
}

/** `config/app.json` `legal.termsUrl` / `.privacyUrl` and the support address (null while BLOCKED). */
data class LegalLinks(val termsUrl: String?, val privacyUrl: String?, val supportEmail: String?)

/** Opening things outside the app: in-app browser, SMS compose, share sheet, mail, store pages. */
object ExternalActions {
    /** In-app browser (Custom Tabs) for legal links. */
    fun openInAppBrowser(context: Context, url: String) {
        try {
            CustomTabsIntent.Builder().build().launchUrl(context, Uri.parse(url))
        } catch (_: android.content.ActivityNotFoundException) {
        }
    }

    /** Android Sharesheet with [text] (`groups.invite.layout.share`: `Intent.createChooser(ACTION_SEND text/plain)`). */
    fun share(context: Context, text: String) {
        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
        start(context, Intent.createChooser(send, null))
    }

    /** SMS compose addressed to [phone] with [body] (`ACTION_SENDTO smsto:` + `sms_body`): the person sees it before sending. */
    fun smsCompose(context: Context, phone: String, body: String) {
        val intent = Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:" + Uri.encode(phone))).putExtra("sms_body", body)
        start(context, intent)
    }

    fun mail(context: Context, address: String) {
        start(context, Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$address")))
    }

    fun view(context: Context, url: String) {
        start(context, Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }

    fun start(context: Context, intent: Intent) {
        try {
            if (context !is android.app.Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
        } catch (_: android.content.ActivityNotFoundException) {
        }
    }
}
