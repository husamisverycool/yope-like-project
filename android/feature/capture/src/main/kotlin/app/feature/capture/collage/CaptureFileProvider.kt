package app.feature.capture.collage

import androidx.core.content.FileProvider

/**
 * collage.share: hands the shared page to the Sharesheet as `content://` (read grant only). Declared in this module's
 * manifest (authority `${applicationId}.capture.files`, paths `@xml/capture_shared_files`); the app process installs it
 * at start, so the class must exist or every launch fails ("Unable to get provider").
 */
class CaptureFileProvider : FileProvider()
