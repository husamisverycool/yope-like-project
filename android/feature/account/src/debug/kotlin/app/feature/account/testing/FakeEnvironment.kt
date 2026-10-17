package app.feature.account.testing

import android.app.Activity
import android.net.Uri
import app.feature.account.AccountEnvironment
import app.feature.account.InviteLinks
import app.feature.account.invite.InvitePreviewClient
import app.feature.account.invite.InvitePreviewResult
import app.feature.account.paywall.PlanOption
import app.feature.account.paywall.PlanPeriod
import app.feature.account.paywall.PremiumGateway
import app.feature.account.paywall.PremiumResult
import app.feature.account.platform.AccountStores
import app.feature.account.platform.AgeRefusal
import app.feature.account.platform.ContactsSource
import app.feature.account.platform.DeviceContact
import app.feature.account.platform.ImageImporter
import app.feature.account.platform.LegalLinks
import app.model.DeepLinkCodec
import app.model.SessionPromptGate
import app.ui.theme.AppearanceSettings
import app.ui.theme.MemoryAppearanceSettings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import java.io.File
import java.time.Clock
import java.time.ZoneId
import java.time.ZoneOffset

/** DEBUG only: in-memory [AccountStores]. */
class FakeStores : AccountStores {
    override var pendingInviteToken: String? = null
    override var referrerChecked: Boolean = false
    val onboarded = mutableSetOf<String>()
    var refusal: AgeRefusal? = null
    override fun isOnboardingDone(userId: String) = userId in onboarded
    override fun setOnboardingDone(userId: String) {
        onboarded += userId
    }
    override var devicePagesShown: Boolean = false

    override fun ageRefusal(): AgeRefusal? = refusal
    override fun rememberAgeRefusal(refusal: AgeRefusal) {
        this.refusal = refusal
    }
}

/** DEBUG only: a premium gateway with two plans and scripted outcomes. */
class FakePremium : PremiumGateway {
    val active = MutableStateFlow(false)
    override val isActive = active
    /** Owner decision 7: $35.99 a year with a 1-week free trial, $3.99 a month. */
    var plans = listOf(PlanOption(PlanPeriod.Yearly, "$35.99", null, trialDuration = "1 week"), PlanOption(PlanPeriod.Monthly, "$3.99", null))
    var purchaseResult = PremiumResult.Done
    var restoreResult: Pair<PremiumResult, Boolean> = PremiumResult.Done to false
    override suspend fun refresh(): Boolean = active.value
    override suspend fun plans(): List<PlanOption> = plans
    override suspend fun purchase(activity: Activity, plan: PlanOption): PremiumResult = purchaseResult.also { if (it == PremiumResult.Done) active.value = true }
    override suspend fun restore(): Pair<PremiumResult, Boolean> = restoreResult
}

/** DEBUG only: the domain tests use for invite links. */
const val TEST_DOMAIN = "invite.example.test"

/** DEBUG only: an [AccountEnvironment] over fakes (fixed clock and zone, no Play services, no OS permissions). */
fun fakeEnvironment(
    backend: FakeAccountBackend = FakeAccountBackend(),
    stores: FakeStores = FakeStores(),
    preview: InvitePreviewResult = InvitePreviewResult.Valid("Sunday dinners", null, "Ana"),
    premium: FakePremium = FakePremium(),
    contacts: List<DeviceContact> = emptyList(),
    granted: Set<String> = emptySet(),
    sdkInt: Int = 36,
    scope: CoroutineScope? = null,
    launchToCamera: Boolean = false,
    appearance: AppearanceSettings = MemoryAppearanceSettings(),
): AccountEnvironment = AccountEnvironment(
    backend = backend,
    stores = stores,
    inviteLinks = InviteLinks(DeepLinkCodec(TEST_DOMAIN), TEST_DOMAIN),
    invitePreview = InvitePreviewClient { preview },
    premium = premium,
    contacts = object : ContactsSource {
        override suspend fun contacts() = contacts
    },
    images = ImageImporter { _: Uri -> File.createTempFile("picked", ".jpg") },
    legal = LegalLinks(termsUrl = "https://example.test/terms", privacyUrl = "https://example.test/privacy", supportEmail = null),
    clock = Clock.fixed(backend.now, ZoneOffset.UTC),
    zone = { ZoneId.of("UTC") },
    sdkInt = sdkInt,
    promptGate = SessionPromptGate(),
    smsUserConsent = false,
    region = { "US" },
    isGranted = { it in granted },
    launchToCamera = launchToCamera,
    appearance = appearance,
).let { env -> if (scope != null) env.copyWithScope(scope) else env }

private fun AccountEnvironment.copyWithScope(scope: CoroutineScope) = AccountEnvironment(
    backend, stores, inviteLinks, invitePreview, premium, contacts, images, legal, clock, zone, sdkInt, promptGate, signUp,
    appScope = scope, optimistic = optimistic, smsUserConsent = smsUserConsent, region = region, isGranted = isGranted,
    launchToCamera = launchToCamera, toasts = toasts, appearance = appearance,
)
