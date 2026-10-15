package app.widget

import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp

/**
 * The size classes the photo widget lays out for (Glance `SizeMode.Responsive`). Their cell
 * footprints mirror the iOS widget families (Apple HIG, Widgets: small 2×2, medium 4×2,
 * large 4×4 home-screen cells) so both platforms offer the same three sizes
 * (`widget.home.small` / `.medium` / `.large` in docs/SURFACES.md).
 */
enum class WidgetSizeClass(val columns: Int, val rows: Int) {
    Small(columns = 2, rows = 2),
    Medium(columns = 4, rows = 2),
    Large(columns = 4, rows = 4);

    /** The smallest size a widget spanning these cells gets on a typical phone grid. */
    val minSize: DpSize get() = PlatformWidgetGrid.minSize(columns, rows)

    companion object {
        val breakpoints: Set<DpSize> get() = entries.map { it.minSize }.toSet()

        /** The largest class that fits in [size]. */
        fun of(size: DpSize): WidgetSizeClass =
            entries.lastOrNull { size.width >= it.minSize.width && size.height >= it.minSize.height } ?: Small
    }
}

/**
 * Android's documented home-screen cell sizes (PLATFORM): "n x m cells — portrait
 * (73n − 16) × (118m − 16) dp, landscape (142n − 15) × (66m − 15) dp; use the portrait widths and
 * the landscape heights for minimum sizes" —
 * https://developer.android.com/develop/ui/views/appwidgets/layouts#anatomy_determining_size
 */
object PlatformWidgetGrid {
    private const val PORTRAIT_DP_PER_COLUMN = 73
    private const val PORTRAIT_WIDTH_INSET_DP = 16
    private const val LANDSCAPE_DP_PER_ROW = 66
    private const val LANDSCAPE_HEIGHT_INSET_DP = 15

    fun minSize(columns: Int, rows: Int): DpSize = DpSize(
        (PORTRAIT_DP_PER_COLUMN * columns - PORTRAIT_WIDTH_INSET_DP).dp,
        (LANDSCAPE_DP_PER_ROW * rows - LANDSCAPE_HEIGHT_INSET_DP).dp,
    )
}
