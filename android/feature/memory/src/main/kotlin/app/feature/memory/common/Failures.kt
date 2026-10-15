package app.feature.memory.common

import app.data.error.ApiError
import app.data.error.DataError
import app.data.error.DataException
import kotlinx.coroutines.CancellationException

/** What a failed data call means for a memory screen (the copy is chosen by each screen). */
enum class Failure {
    /** No connection (DataError.Network): the screen's offline state. */
    Offline,

    /** The row is gone or not visible (request_not_found, post_not_found, a missing row). */
    NotFound,

    /** tribute_closed: the request is past its due time. */
    Closed,

    /** post_not_eligible: a tribute photo that is neither yours nor one you are in. */
    NotEligible,

    /** invalid_birthday / invalid_argument on set_birthday. */
    InvalidDate,

    /** Anything else (including a data layer that is not configured yet). */
    Other,
}

/** Classifies [error]; cancellation is rethrown so structured concurrency keeps working. */
fun failureOf(error: Throwable): Failure {
    if (error is CancellationException) throw error
    val data = (error as? DataException)?.error ?: return Failure.Other
    return when (data) {
        DataError.Network -> Failure.Offline
        is DataError.Api -> when (data.code) {
            ApiError.RequestNotFound, ApiError.PostNotFound -> Failure.NotFound
            ApiError.TributeClosed -> Failure.Closed
            ApiError.PostNotEligible -> Failure.NotEligible
            ApiError.InvalidBirthday, ApiError.InvalidArgument -> Failure.InvalidDate
            else -> Failure.Other
        }
        else -> Failure.Other
    }
}

/** Runs [block]; a failure comes back as [Result.failure] after classification. */
inline fun <T> attempt(block: () -> T): Result<T> = try {
    Result.success(block())
} catch (e: CancellationException) {
    throw e
} catch (e: Throwable) {
    Result.failure(e)
}
