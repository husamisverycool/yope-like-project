package app.main.e2e

import android.util.Size
import androidx.camera.core.CameraInfo
import androidx.camera.core.SurfaceRequest
import androidx.camera.core.impl.CameraInternal
import androidx.test.platform.app.InstrumentationRegistry
import app.feature.social.viewer.SelfieCamera
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import java.io.File
import java.lang.reflect.InvocationHandler
import java.lang.reflect.Proxy

/**
 * The end-to-end run's front camera for the viewer's selfie layer ([E2eRunner] installs it through
 * `SelfieCameras.factory`), as [FixtureCameraController] is for the main camera: the emulator camera cannot take a real
 * photo. The layer counts as live once the camera offers a preview (`viewer.selfiereaction`: capture waits for the first
 * frame), so [start] offers one: a [SurfaceRequest] for a camera that produces no frames (the circle stays dark, as the
 * main camera's viewfinder does in this run). A capture writes the packaged sample photo (`e2e-photo.jpg`). Everything
 * after the capture — the upload, `react_with_selfie`, the face stack, the Reactions sheet — is the app's own code against
 * the real stack.
 */
class FixtureSelfieCamera : SelfieCamera {
    private val request = MutableStateFlow<SurfaceRequest?>(null)
    override val preview: StateFlow<SurfaceRequest?> = request

    override suspend fun start() {
        request.value = SurfaceRequest(Size(PREVIEW_WIDTH, PREVIEW_HEIGHT), frameless(CameraInternal::class.java)) {}
    }

    override suspend fun capture(output: File): File = withContext(Dispatchers.IO) {
        output.parentFile?.mkdirs()
        InstrumentationRegistry.getInstrumentation().context.assets.open(ASSET).use { input ->
            output.outputStream().use { input.copyTo(it) }
        }
        output
    }

    override suspend fun stop() {
        request.value?.willNotProvideSurface()
        request.value = null
    }

    private companion object {
        const val ASSET = "e2e-photo.jpg"
        const val PREVIEW_WIDTH = 640
        const val PREVIEW_HEIGHT = 480

        /**
         * A camera (CameraX's internal interfaces) that answers every question with nothing: no frames, no info. Only
         * what the viewfinder reads of the request is called (`camera.cameraInfo.implementationType`, to pick its
         * implementation mode), and that answers null (the default mode).
         */
        @Suppress("UNCHECKED_CAST")
        fun <T> frameless(type: Class<T>): T {
            lateinit var self: Any
            val handler = InvocationHandler { _, method, args ->
                when {
                    method.name == "equals" && args?.size == 1 -> self === args[0]
                    method.name == "hashCode" && method.parameterCount == 0 -> System.identityHashCode(self)
                    method.name == "toString" && method.parameterCount == 0 -> "e2e frameless ${type.simpleName}"
                    method.returnType == CameraInfo::class.java || method.returnType.isInterface && CameraInfo::class.java.isAssignableFrom(method.returnType) ->
                        frameless(method.returnType)
                    method.returnType == java.lang.Boolean.TYPE -> false
                    method.returnType == Integer.TYPE -> 0
                    method.returnType == java.lang.Long.TYPE -> 0L
                    method.returnType == java.lang.Float.TYPE -> 0f
                    method.returnType == java.lang.Double.TYPE -> 0.0
                    else -> null
                }
            }
            self = Proxy.newProxyInstance(type.classLoader, arrayOf(type), handler)
            return self as T
        }
    }
}
