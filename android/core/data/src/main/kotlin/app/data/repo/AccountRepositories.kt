package app.data.repo

import app.data.model.Block
import app.data.model.Device
import app.data.model.DevicePlatform
import app.data.model.Entitlement
import app.data.model.NotificationSettings
import app.data.model.PublicAppConfig
import app.data.model.PublicAppConfigRow
import app.data.model.ReportTargetKind
import app.data.remote.Api
import app.data.remote.Rpc
import app.data.remote.Tables
import app.model.QuietHours
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.builtins.serializer
import java.time.Clock
import java.time.DateTimeException
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId

/** Blocking and reporting (docs/API.md §5.6, §6.3). */
class SafetyRepository(private val api: Api) {

    /** People you blocked (the blocked person never sees the row). */
    suspend fun blocked(): List<Block> = api.select(Tables.BLOCKS, Block.serializer()) { order("created_at", Order.DESCENDING) }

    /** Idempotent. Works in both directions for content visibility. */
    suspend fun block(userId: String) = api.rpcUnit(Rpc.BlockUser) { put("p_user_id", userId) }

    suspend fun unblock(userId: String) = api.rpcUnit(Rpc.UnblockUser) { put("p_user_id", userId) }

    /** Returns the report id. A block does not stop you reporting. */
    suspend fun report(kind: ReportTargetKind, targetId: String, reason: String): String =
        api.rpc(Rpc.Report, String.serializer()) {
            put("p_target_kind", kind.wire)
            put("p_target_id", targetId)
            put("p_reason", reason)
        }
}

/**
 * Quiet hours (docs/API.md §5.21, `set_quiet_hours`). [quietHours] is what the push layer reads
 * (`QuietHoursSource`) to deliver alerts silently during the window.
 */
class SettingsRepository(private val api: Api) {
    private val current = MutableStateFlow<Pair<QuietHours, ZoneId>?>(null)

    /** The last known quiet window in its zone, or null for none. */
    val quietHours: StateFlow<Pair<QuietHours, ZoneId>?> = current.asStateFlow()

    /** Your row; null = no quiet hours. */
    suspend fun notificationSettings(): NotificationSettings? =
        api.selectSingleOrNull(Tables.NOTIFICATION_SETTINGS, NotificationSettings.serializer()) {
            filter { eq("user_id", api.requireUserId()) }
        }.also(::publish)

    /** Both times null = no quiet hours; `end <= start` wraps past midnight; [timeZone] = the device's zone. */
    suspend fun setQuietHours(start: LocalTime?, end: LocalTime?, timeZone: String?): NotificationSettings =
        api.rpc(Rpc.SetQuietHours, NotificationSettings.serializer()) {
            put("p_start", start)
            put("p_end", end)
            put("p_time_zone", timeZone)
        }.also(::publish)

    suspend fun clearQuietHours(): NotificationSettings = setQuietHours(null, null, null)

    /** §14.3 the reveal push of overnight photos on or off (`set_overnight_alerts`; `notification_settings.overnight`). */
    suspend fun setOvernightAlerts(on: Boolean): NotificationSettings =
        api.rpc(Rpc.SetOvernightAlerts, NotificationSettings.serializer()) { put("p_on", on) }.also(::publish)

    internal fun reset() {
        current.value = null
    }

    private fun publish(settings: NotificationSettings?) {
        val start = settings?.quietStart
        val end = settings?.quietEnd
        val zone = settings?.timeZone?.let { tz -> try { ZoneId.of(tz) } catch (_: DateTimeException) { null } }
        current.value = if (start != null && end != null && zone != null) QuietHours(start, end) to zone else null
    }
}

/** Push registration (docs/API.md §5.20, `register_device` / `unregister_device`). */
class DeviceRepository(private val api: Api) {

    /** Registers this install's FCM token (Android sends no iOS-only tokens). Upsert by token. */
    suspend fun register(fcmToken: String): Device = api.rpc(Rpc.RegisterDevice, Device.serializer()) {
        put("p_platform", DevicePlatform.Android.wire)
        put("p_push_token", fcmToken)
        put("p_push_to_start_token", null as String?)
        put("p_widget_push_token", null as String?)
    }

    /** Call before signing out (§2). */
    suspend fun unregister(fcmToken: String) = api.rpcUnit(Rpc.UnregisterDevice) { put("p_push_token", fcmToken) }

    suspend fun devices(): List<Device> = api.select(Tables.DEVICES, Device.serializer()) { order("created_at", Order.ASCENDING) }
}

/** Your entitlements (docs/API.md §5.22). Premium gates only video posts. */
class EntitlementRepository(private val api: Api, private val clock: Clock = Clock.systemUTC()) {

    suspend fun entitlements(): List<Entitlement> = api.select(Tables.ENTITLEMENTS, Entitlement.serializer())

    suspend fun isPremium(now: Instant = clock.instant()): Boolean =
        entitlements().any { it.entitlement == PREMIUM && it.isActive(now) }

    companion object {
        const val PREMIUM = "premium"
    }
}

/** The public tunables (§5.25; readable signed out). */
class AppConfigRepository(private val api: Api) {
    suspend fun publicConfig(): PublicAppConfig =
        PublicAppConfig.from(api.select(Tables.PUBLIC_APP_CONFIG, PublicAppConfigRow.serializer()))
}
