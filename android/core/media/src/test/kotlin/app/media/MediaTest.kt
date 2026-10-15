package app.media

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import androidx.camera.core.CameraSelector.LENS_FACING_BACK
import androidx.camera.core.CameraSelector.LENS_FACING_EXTERNAL
import androidx.camera.core.CameraSelector.LENS_FACING_FRONT
import androidx.exifinterface.media.ExifInterface
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.GraphicsMode
import java.io.File
import java.io.IOException

@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class MediaTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val dir = File(context.cacheDir, "media-test").apply { deleteRecursively(); mkdirs() }

    private fun jpegWithGps(w: Int, h: Int, orientation: Int = ExifInterface.ORIENTATION_NORMAL): File {
        val file = File(dir, "in.jpg")
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).apply { eraseColor(Color.GRAY) }
        file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.JPEG, 90, it) }
        ExifInterface(file).apply {
            setLatLong(52.52, 13.405)
            setAttribute(ExifInterface.TAG_GPS_ALTITUDE, "34/1")
            setAttribute(ExifInterface.TAG_ORIENTATION, orientation.toString())
            saveAttributes()
        }
        assertTrue(ExifInterface(file).latLong != null)
        return file
    }

    @Test fun encodeDownscalesRotatesAndDropsAllLocation() {
        val input = jpegWithGps(400, 200, ExifInterface.ORIENTATION_ROTATE_90)
        val out = ImageEncoder.encode(input, File(dir, "out.jpg"), EncodeOptions(maxLongEdgePx = 100, jpegQuality = 80))
        assertEquals(50, out.width)
        assertEquals(100, out.height)
        val exif = ExifInterface(out.file)
        assertNull(exif.latLong)
        ImageEncoder.GPS_TAGS.forEach { assertNull(it, exif.getAttribute(it)) }
        assertEquals(ExifInterface.ORIENTATION_UNDEFINED, exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_UNDEFINED))
    }

    @Test fun smallImagesAreNotUpscaled() {
        val out = ImageEncoder.encode(jpegWithGps(60, 40), File(dir, "small.jpg"), EncodeOptions(1000, 80))
        assertEquals(60, out.width)
        assertEquals(40, out.height)
    }

    @Test fun stripLocationRemovesGpsInPlace() {
        val file = jpegWithGps(20, 20)
        ImageEncoder.stripLocation(file)
        val exif = ExifInterface(file)
        assertNull(exif.latLong)
        assertNull(exif.getAttribute(ExifInterface.TAG_GPS_ALTITUDE))
        assertTrue(ImageEncoder.GPS_TAGS.contains(ExifInterface.TAG_GPS_LATITUDE))
    }

    @Test(expected = IOException::class) fun rejectsNonImages() {
        val junk = File(dir, "junk.jpg").apply { writeText("not an image") }
        ImageEncoder.encode(junk, File(dir, "x.jpg"), EncodeOptions(100, 80))
    }

    @Test fun permissionStates() {
        assertEquals(PermissionState.Granted, MediaPermissions.resolve(granted = true, showRationale = false, requestedBefore = true))
        assertEquals(PermissionState.NotRequested, MediaPermissions.resolve(granted = false, showRationale = false, requestedBefore = false))
        assertEquals(PermissionState.Denied, MediaPermissions.resolve(granted = false, showRationale = true, requestedBefore = true))
        assertEquals(PermissionState.PermanentlyDenied, MediaPermissions.resolve(granted = false, showRationale = false, requestedBefore = true))
        MediaPermissions.markRequested(context, MediaPermission.Camera)
        assertTrue(MediaPermissions.wasRequested(context, MediaPermission.Camera))
    }

    @Test fun photoLibraryUsesThePickerWithoutPermission() {
        assertEquals(PhotoLibraryAccess.PickerOnly, PhotoLibraryAccess.current(context))
        assertEquals(PhotoLibraryAccess.Partial, PhotoLibraryAccess.resolve(fullGranted = false, userSelectedGranted = true))
        assertEquals(PhotoLibraryAccess.Full, PhotoLibraryAccess.resolve(fullGranted = true, userSelectedGranted = true))
    }

    @Test fun dualCaptureIsConcurrentOnlyWithFeatureAndAFrontBackPair() {
        val pair = listOf(listOf(LENS_FACING_BACK, LENS_FACING_FRONT))
        assertEquals(DualCaptureMode.Concurrent, DualCameraSupport.mode(true, pair))
        assertEquals(DualCaptureMode.Sequential, DualCameraSupport.mode(false, pair))
        assertEquals(DualCaptureMode.Sequential, DualCameraSupport.mode(true, emptyList()))
        assertEquals(DualCaptureMode.Sequential, DualCameraSupport.mode(true, listOf(listOf(LENS_FACING_BACK, LENS_FACING_EXTERNAL))))
        assertEquals(1, DualCameraSupport.frontBackPair(listOf(listOf(LENS_FACING_BACK, LENS_FACING_BACK), listOf(LENS_FACING_FRONT, LENS_FACING_BACK))))
    }

    @Test fun readsTheConcurrentCameraFeature() {
        val pm = shadowOf(context.packageManager)
        pm.setSystemFeature(PackageManager.FEATURE_CAMERA_CONCURRENT, false)
        assertEquals(false, DualCameraSupport.hasConcurrentFeature(context))
        pm.setSystemFeature(PackageManager.FEATURE_CAMERA_CONCURRENT, true)
        assertEquals(true, DualCameraSupport.hasConcurrentFeature(context))
    }
}
