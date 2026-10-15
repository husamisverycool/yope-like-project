package app.feature.account

import androidx.compose.runtime.staticCompositionLocalOf
import app.feature.account.data.AccountBackend
import app.feature.account.invite.InvitePreviewClient
import app.feature.account.paywall.PremiumGateway
import app.feature.account.platform.AccountStores
import app.feature.account.platform.ContactsSource
import app.feature.account.platform.ImageImporter
import app.feature.account.platform.LegalLinks
import app.model.DeepLink
import app.model.DeepLinkCodec
import app.model.SessionPromptGate
import java.time.Clock
import java.time.ZoneId

/** Invite links: `https://<domain>/i/<token>` (null while `config/app.json` `domain` is BLOCKED). */
class InviteLinks(private val codec: DeepLinkCodec, val domain: String?) {
    fun url(token: String): String? = codec.format(DeepLink.Invite(token))

    /** The web service's preview for apps before joining (design/surfaces/invite.web.md → Data). */
    fun previewUrl(token: String): String? = domain?.let { "https://$it${DeepLinkCodec.INVITE_PATH}$token/preview.json" }
}

/**
 * Optimistic writes that outlive the screen that made them (leave group): the group disappears from
 * groups.list at once and comes back if the server refuses.
 */
class OptimisticState {
    val leftGroups = kotlinx.coroutines.flow.MutableStateFlow<Set<String>>(emptySet())
}

/** The phone number being verified, shared by auth.phone → auth.code (and the resend). */
class SignUpSession {
    @Volatile var phoneE164: String? = null
    @Volatile var phoneDisplay: String? = null
    @Volatile var codeSentAtMillis: Long? = null
}

/**
 * Everything the account screens need from outside the composition: the data layer seam, platform
 * services and device stores. The app shell creates the real one (`app.main`); tests pass fakes.
 */
class AccountEnvironment(
    val backend: AccountBackend,
    val stores: AccountStores,
    val inviteLinks: InviteLinks,
    val invitePreview: InvitePreviewClient,
    val premium: PremiumGateway,
    val contacts: ContactsSource,
    val images: ImageImporter,
    val legal: LegalLinks,
    val clock: Clock = Clock.systemUTC(),
    val zone: () -> ZoneId = { ZoneId.systemDefault() },
    val sdkInt: Int = android.os.Build.VERSION.SDK_INT,
    val promptGate: SessionPromptGate = SessionPromptGate.process,
    val signUp: SignUpSession = SignUpSession(),
    /** Process-lifetime scope for writes that finish after their screen is gone (optimistic leave). */
    val appScope: kotlinx.coroutines.CoroutineScope = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.SupervisorJob() + kotlinx.coroutines.Dispatchers.Main.immediate),
    val optimistic: OptimisticState = OptimisticState(),
    /** SMS User Consent (Play services); off in tests and where Play services are missing. */
    val smsUserConsent: Boolean = true,
    /** The device region for the calling-code prefill (ISO 3166 alpha-2), e.g. from the SIM / network. */
    val region: () -> String? = { null },
    /** Whether a runtime permission is granted (`ContextCompat.checkSelfPermission`). */
    val isGranted: (permission: String) -> Boolean = { false },
)

val LocalAccountEnvironment = staticCompositionLocalOf<AccountEnvironment> { error("AccountEnvironment not provided") }
