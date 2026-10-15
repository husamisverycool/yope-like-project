package app.data.error

/**
 * A [DataError] as a short string, for places that only carry strings (WorkManager output data,
 * persisted upload drafts): `api:<code>`, `db:<kind>`, `auth:<kind>`, `storage:<kind>`, `network`,
 * `not_signed_in`, `not_configured`, `file_unavailable`, `unexpected`.
 */
object DataErrorCodec {
    fun encode(error: DataError): String = when (error) {
        is DataError.Api -> "api:" + (if (error.code == ApiError.Unknown) error.raw else error.code.wire)
        is DataError.Database -> "db:" + error.kind.name
        is DataError.Auth -> "auth:" + error.kind.name
        is DataError.Storage -> "storage:" + error.kind.name
        DataError.Network -> "network"
        DataError.NotSignedIn -> "not_signed_in"
        DataError.NotConfigured -> "not_configured"
        DataError.FileUnavailable -> "file_unavailable"
        is DataError.Unexpected -> "unexpected"
    }

    fun decode(code: String?): DataError? {
        if (code.isNullOrEmpty()) return null
        val kind = code.substringBefore(':')
        val value = code.substringAfter(':', "")
        return when (kind) {
            "api" -> ApiError.fromWire(value).let { DataError.Api(it, value, it.httpStatus.takeIf { s -> s > 0 }, null) }
            "db" -> DataError.Database(enumOr(value, DbFailure.Other), null, null)
            "auth" -> DataError.Auth(enumOr(value, AuthFailure.Other), null)
            "storage" -> DataError.Storage(enumOr(value, StorageFailure.Other), null, null)
            "network" -> DataError.Network
            "not_signed_in" -> DataError.NotSignedIn
            "not_configured" -> DataError.NotConfigured
            "file_unavailable" -> DataError.FileUnavailable
            else -> DataError.Unexpected(null)
        }
    }

    private inline fun <reified E : Enum<E>> enumOr(name: String, fallback: E): E =
        enumValues<E>().firstOrNull { it.name == name } ?: fallback
}
