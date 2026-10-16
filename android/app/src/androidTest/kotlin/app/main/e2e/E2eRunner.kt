package app.main.e2e

import android.content.Context
import android.os.Bundle
import android.util.Log
import androidx.test.runner.AndroidJUnitRunner
import app.data.DataGraph
import app.data.DataOptions
import app.data.SupabaseConfig
import app.feature.account.AccountEnvironment
import app.feature.account.AccountEnvironments
import app.feature.account.InviteLinks
import app.feature.account.invite.HttpInvitePreviewClient
import app.feature.capture.camera.CameraControllers
import app.model.DeepLinkCodec

/**
 * The instrumentation runner of the end-to-end journey ([JourneyTest]). It runs before the app's `Application.onCreate`
 * and, when the instrumentation arguments name a Supabase stack, points the real app at it through the seams the app
 * already has for tests:
 * - `DataGraph.override`: the data layer talks to `supabaseUrl` with `supabaseAnonKey` (debug builds allow plain HTTP to
 *   10.0.2.2 / 127.0.0.1 only: src/debug/res/xml/debug_network_security.xml);
 * - `AccountEnvironments.override`: the real environment with an invite-link host ([E2E_INVITE_HOST]), because
 *   `config/app.json` `domain` is BLOCKED and invite links do not exist without one. The web preview service is not part
 *   of this run, so the preview is "not configured" and `join_group` decides (the app's own path for that case);
 * - `CameraControllers.factory`: [FixtureCameraController], because the emulator camera cannot take a real photo.
 *
 * Without the arguments nothing is changed and [JourneyTest] skips. This file lives in the test APK only: release (and
 * plain debug) builds contain none of it.
 *
 * Arguments: `-e supabaseUrl http://10.0.2.2:54321 -e supabaseAnonKey <anon key>` (Gradle:
 * `-Pandroid.testInstrumentationRunnerArguments.supabaseUrl=…`).
 */
class E2eRunner : AndroidJUnitRunner() {
    override fun onCreate(arguments: Bundle?) {
        val url = arguments?.getString(ARG_URL)?.takeIf { it.isNotBlank() }
        val key = arguments?.getString(ARG_ANON_KEY)?.takeIf { it.isNotBlank() }
        if (url != null && key != null) {
            configure(targetContext.applicationContext, SupabaseConfig(url.trimEnd('/'), key))
            configured = true
            Log.i(TAG, "end-to-end run against $url")
        } else {
            Log.i(TAG, "no supabaseUrl / supabaseAnonKey arguments: the end-to-end journey skips")
        }
        super.onCreate(arguments)
    }

    private fun configure(app: Context, config: SupabaseConfig) {
        DataGraph.override(DataGraph(app, config, DataOptions.default(app)))
        // The app's own environment (built over the graph above), with invite links on the test host. Every device-backed
        // member of the real environment is carried over; the rest are the constructor's defaults, as in the app.
        val real = AccountEnvironments.get(app)
        val links = InviteLinks(DeepLinkCodec(E2E_INVITE_HOST), domain = null)
        AccountEnvironments.override(
            AccountEnvironment(
                backend = real.backend,
                stores = real.stores,
                inviteLinks = links,
                invitePreview = HttpInvitePreviewClient(links),
                premium = real.premium,
                contacts = real.contacts,
                images = real.images,
                legal = real.legal,
                region = real.region,
                isGranted = real.isGranted,
                appearance = real.appearance,
            ),
        )
        CameraControllers.factory = { context, _ -> FixtureCameraController(context) }
    }

    companion object {
        const val TAG = "E2E"
        const val ARG_URL = "supabaseUrl"
        const val ARG_ANON_KEY = "supabaseAnonKey"

        /** Invite-link host of the run (RFC 6761 `.test`: never resolves, nothing outside the test opens these links). */
        const val E2E_INVITE_HOST = "invite.e2e.test"

        /** Whether the arguments named a stack (read by the tests). */
        @Volatile var configured: Boolean = false
            private set
    }
}
