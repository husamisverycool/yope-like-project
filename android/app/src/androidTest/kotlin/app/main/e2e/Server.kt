package app.main.e2e

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * What the worker's scheduler does with the service role, done by the journey at a time of its choosing: the test stack's
 * URL and service role key come from the instrumentation arguments ([E2eRunner]); the app never sees the key.
 */
internal object Server {
    /** The latest reveal time among the photos developing (`developing_posts.develops_at`), or null when none develop. */
    fun latestDevelopsAt(): String? {
        val rows = JSONArray(request("GET", "/rest/v1/developing_posts?select=develops_at&order=develops_at.desc&limit=1", null))
        return if (rows.length() == 0) null else rows.getJSONObject(0).getString("develops_at")
    }

    /** `due_developed_posts(p_now)`: the scheduler's tick at [at] (the photos due by then become posts). Returns the posts. */
    fun developedPosts(at: String): JSONArray =
        JSONArray(request("POST", "/rest/v1/rpc/due_developed_posts", JSONObject().put("p_now", at).toString()))

    private fun request(method: String, path: String, body: String?): String {
        val url = E2eRunner.supabaseUrl ?: throw AssertionError("no supabaseUrl instrumentation argument")
        val key = E2eRunner.serviceRoleKey ?: throw AssertionError("no serviceRoleKey instrumentation argument: the reveal needs the test stack's service role")
        val connection = URL(url + path).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = method
            connection.connectTimeout = TIMEOUT_MS
            connection.readTimeout = TIMEOUT_MS
            connection.setRequestProperty("apikey", key)
            connection.setRequestProperty("Authorization", "Bearer $key")
            connection.setRequestProperty("Accept", "application/json")
            if (body != null) {
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                connection.outputStream.use { it.write(body.toByteArray()) }
            }
            val status = connection.responseCode
            val text = (if (status in 200..299) connection.inputStream else connection.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) throw AssertionError("$method $path: HTTP $status $text")
            return text
        } finally {
            connection.disconnect()
        }
    }

    private const val TIMEOUT_MS = 30_000
}
