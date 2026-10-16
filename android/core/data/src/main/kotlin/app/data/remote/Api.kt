package app.data.remote

import app.data.error.DataError
import app.data.error.DataException
import app.data.error.dataCall
import app.data.model.DataJson
import app.data.model.InstantSerializer
import app.data.model.LocalTimeSerializer
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.request.SelectRequestBuilder
import kotlinx.serialization.KSerializer
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.util.Base64

/** RPC arguments: [put] always sends the key (null → JSON null); [opt] omits a null value. */
class RpcArgs internal constructor() {
    internal val values = LinkedHashMap<String, JsonElement>()

    fun put(key: String, value: String?) { values[key] = JsonPrimitive(value) }
    fun put(key: String, value: Int?) { values[key] = JsonPrimitive(value) }
    fun put(key: String, value: Boolean?) { values[key] = JsonPrimitive(value) }
    fun put(key: String, value: Instant?) { values[key] = JsonPrimitive(value?.let(InstantSerializer::format)) }
    fun put(key: String, value: LocalDate?) { values[key] = JsonPrimitive(value?.toString()) }
    fun put(key: String, value: LocalTime?) { values[key] = JsonPrimitive(value?.let(LocalTimeSerializer::format)) }
    fun put(key: String, value: List<String>?) { values[key] = value?.let { list -> JsonArray(list.map(::JsonPrimitive)) } ?: JsonNull }

    fun opt(key: String, value: String?) { if (value != null) put(key, value) }
    fun opt(key: String, value: Int?) { if (value != null) put(key, value) }
    fun opt(key: String, value: Boolean?) { if (value != null) put(key, value) }
    fun opt(key: String, value: Instant?) { if (value != null) put(key, value) }
    fun opt(key: String, value: LocalDate?) { if (value != null) put(key, value) }
    fun opt(key: String, value: LocalTime?) { if (value != null) put(key, value) }
    fun opt(key: String, value: List<String>?) { if (value != null) put(key, value) }

    /** An integer array (`smallint[]`, e.g. a voice waveform: `p_voice_levels`); omitted when null. */
    fun optInts(key: String, value: List<Int>?) { if (value != null) values[key] = JsonArray(value.map(::JsonPrimitive)) }

    fun toJson(): JsonObject = JsonObject(values)
}

fun rpcArgs(rpc: Rpc, build: RpcArgs.() -> Unit = {}): JsonObject = RpcArgs().apply(build).toJson().also { rpc.check(it.keys) }

/**
 * The thin layer over supabase-kt every repository uses: RPC calls checked against [Rpc], table
 * reads decoded with [DataJson], and every failure rethrown as a typed [DataException].
 */
class Api(val client: SupabaseClient) {

    /** The signed-in user's id, or null. Falls back to the access token's `sub` claim. */
    val currentUserId: String?
        get() {
            val session = client.auth.currentSessionOrNull() ?: return null
            return session.user?.id ?: jwtSubject(session.accessToken)
        }

    fun requireUserId(): String = currentUserId ?: throw DataException(DataError.NotSignedIn)

    suspend fun rpcRaw(rpc: Rpc, args: JsonObject): String {
        rpc.check(args.keys)
        if (!rpc.anon) requireUserId()
        return dataCall { client.postgrest.rpc(rpc.function, args).data }
    }

    suspend fun <T> rpc(rpc: Rpc, deserializer: KSerializer<T>, build: RpcArgs.() -> Unit = {}): T =
        decode(deserializer, rpcRaw(rpc, rpcArgs(rpc, build)))

    suspend fun <T> rpcList(rpc: Rpc, deserializer: KSerializer<T>, build: RpcArgs.() -> Unit = {}): List<T> =
        decode(ListSerializer(deserializer), rpcRaw(rpc, rpcArgs(rpc, build)))

    /** For `void` RPCs (HTTP 204, empty body). */
    suspend fun rpcUnit(rpc: Rpc, build: RpcArgs.() -> Unit = {}) {
        rpcRaw(rpc, rpcArgs(rpc, build))
    }

    /** `select *` on [table] with filters / order / limit from [request]; RLS decides the rows. */
    suspend fun <T> select(table: String, deserializer: KSerializer<T>, request: SelectRequestBuilder.() -> Unit = {}): List<T> {
        val data = dataCall { client.from(table).select(request = request).data }
        return decode(ListSerializer(deserializer), data)
    }

    suspend fun <T> selectSingleOrNull(table: String, deserializer: KSerializer<T>, request: SelectRequestBuilder.() -> Unit = {}): T? =
        select(table, deserializer) {
            request()
            limit(1)
        }.firstOrNull()

    fun <T> decode(deserializer: KSerializer<T>, data: String): T = try {
        DataJson.decodeFromString(deserializer, data)
    } catch (e: Exception) {
        throw DataException(DataError.Unexpected("decode ${deserializer.descriptor.serialName}: ${e.message}"), e)
    }

    companion object {
        /** The `sub` claim of a JWT (no signature check: it is our own session's token). */
        fun jwtSubject(jwt: String): String? = try {
            val payload = jwt.split('.').getOrNull(1) ?: return null
            val json = String(Base64.getUrlDecoder().decode(payload.padEnd((payload.length + 3) / 4 * 4, '=')))
            DataJson.parseToJsonElement(json).jsonObject["sub"]?.jsonPrimitive?.content
        } catch (_: Exception) {
            null
        }
    }
}
