package app.data.repo

import app.data.error.dataCall
import app.data.media.MediaStorage
import app.data.media.StoragePaths
import app.data.model.Profile
import app.data.model.ProfilePrivate
import app.data.remote.Api
import app.data.remote.Rpc
import app.data.remote.Tables
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import java.io.File
import java.time.LocalDate
import java.util.UUID

/**
 * Your profile (name, avatar), other people's profiles (everyone sharing a group with you), the
 * age gate and the birthday opt-in (docs/API.md §2, §5.1, §5.2). Profile rows are created by the
 * server when the account is created; "create" is the display name sent at OTP sign-in.
 */
class ProfileRepository(private val api: Api, private val storage: MediaStorage) {

    suspend fun me(): Profile = api.select(Tables.PROFILES, Profile.serializer()) {
        filter { eq("id", api.requireUserId()) }
    }.single()

    /** Profiles you may see among [ids] (yourself + people sharing a group with you). */
    suspend fun profiles(ids: Collection<String>): List<Profile> {
        if (ids.isEmpty()) return emptyList()
        return api.select(Tables.PROFILES, Profile.serializer()) { filter { isIn("id", ids.distinct()) } }
    }

    /** Direct update of your own row (§5.0): only `display_name` and `avatar_path`. */
    suspend fun updateProfile(displayName: String? = null, avatarPath: String? = null, clearAvatar: Boolean = false): Profile {
        val uid = api.requireUserId()
        val body = buildMap<String, kotlinx.serialization.json.JsonElement> {
            displayName?.let { put("display_name", JsonPrimitive(it)) }
            when {
                clearAvatar -> put("avatar_path", JsonPrimitive(null as String?))
                avatarPath != null -> put("avatar_path", JsonPrimitive(avatarPath))
            }
        }
        if (body.isEmpty()) return me()
        val data = dataCall {
            api.client.from(Tables.PROFILES).update(JsonObject(body)) {
                select()
                filter { eq("id", uid) }
            }.data
        }
        return api.decode(ListSerializer(Profile.serializer()), data).single()
    }

    /** Uploads a JPEG to `avatars/<uid>/<uuid>.jpg` and returns its path. */
    suspend fun uploadAvatar(jpeg: File): String {
        val path = StoragePaths.avatar(api.requireUserId(), UUID.randomUUID().toString())
        storage.upload(path, jpeg, "image/jpeg") { _, _ -> }
        return path
    }

    /** Uploads [jpeg], points the profile at it, then deletes the previous avatar object (best effort). */
    suspend fun setAvatar(jpeg: File): Profile {
        val previous = me().avatarPath
        val path = uploadAvatar(jpeg)
        val profile = updateProfile(avatarPath = path)
        if (previous != null && previous != path) runCatching { storage.deleteOwnAvatar(previous) }
        return profile
    }

    /** Your `profile_private` row (birthday opt-in, age confirmation). */
    suspend fun privateProfile(): ProfilePrivate? = api.selectSingleOrNull(Tables.PROFILE_PRIVATE, ProfilePrivate.serializer()) {
        filter { eq("user_id", api.requireUserId()) }
    }

    /**
     * The age gate (§2). Fails with `age_gate_not_configured` while the minimum age is not set:
     * treat that as "cannot continue". The birthdate is not stored.
     */
    suspend fun confirmAge(birthdate: LocalDate): ProfilePrivate =
        api.rpc(Rpc.ConfirmAge, ProfilePrivate.serializer()) { put("p_birthdate", birthdate) }

    /** Birthday tributes opt-in. Opting out deletes requests about you that are not yet due. */
    suspend fun setBirthday(birthday: LocalDate?, optIn: Boolean): ProfilePrivate =
        api.rpc(Rpc.SetBirthday, ProfilePrivate.serializer()) {
            put("p_birthday", birthday)
            put("p_opt_in", optIn)
        }
}
