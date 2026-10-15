package app.feature.account.auth

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.designsystem.generated.Tokens
import app.ui.system.SystemRow
import com.google.i18n.phonenumbers.PhoneNumberUtil
import java.text.Collator
import java.util.Locale

/** One entry of the country list: ISO 3166 alpha-2 [region], its localized [name] and calling [code]. */
@Immutable
data class Country(val region: String, val name: String, val code: Int)

/** The countries libphonenumber knows, with the platform's localized names and regional-indicator flags. */
object Countries {
    private const val REGIONAL_INDICATOR_A = 0x1F1E6

    /** The flag emoji of [region] (two regional-indicator symbols; `auth.phone.layout.countryCode` flagArt). */
    fun flag(region: String): String = region.uppercase().filter { it in 'A'..'Z' }.take(2)
        .map { Character.toChars(REGIONAL_INDICATOR_A + (it - 'A')).concatToString() }.joinToString("")

    fun all(locale: Locale = Locale.getDefault()): List<Country> {
        val util = PhoneNumberUtil.getInstance()
        val collator = Collator.getInstance(locale)
        return util.supportedRegions
            .map { Country(it, Locale("", it).getDisplayCountry(locale), util.getCountryCodeForRegion(it)) }
            .sortedWith { a, b -> collator.compare(a.name, b.name) }
    }

    fun name(region: String, locale: Locale = Locale.getDefault()): String = Locale("", region).getDisplayCountry(locale)
}

/**
 * Position of the flag in the phone field (`auth.phone.layout.countryCode`): the flag slot
 * `flagWidth` × `flagHeight` sits `flagLeading` from the field's leading edge and the text keeps
 * `flagToText` clear of it. The tappable area is the platform minimum touch target
 * (`size.global.minTouchTarget.android`) centred on the slot, so the inset is measured to its edge.
 */
object CountryFlagSlot {
    private val layout = Tokens.Layouts.AuthPhoneLayoutCountryCode
    val width: Dp get() = layout.flagWidth.dp
    val height: Dp get() = layout.flagHeight.dp
    private val touch: Dp get() = Tokens.Sizes.globalMinTouchTargetAndroid
    val inset: Dp get() = layout.flagLeading.dp - (touch - width) / 2
    val clearance: Dp get() = (layout.flagLeading + layout.flagWidth + layout.flagToText).dp
    val touchTarget: Dp get() = touch
}

/**
 * The flag at the phone field's leading edge: the emoji fitted into the flag slot; tap → country list.
 * TalkBack reads the country's name as a button.
 */
@Composable
fun CountryFlagButton(region: String, onClick: () -> Unit) {
    val name = remember(region) { Countries.name(region) }
    Box(
        Modifier
            .size(CountryFlagSlot.touchTarget)
            .clickable(role = Role.Button, onClick = onClick)
            .semantics { contentDescription = name },
        contentAlignment = Alignment.Center,
    ) {
        BasicText(
            Countries.flag(region),
            autoSize = TextAutoSize.StepBased(minFontSize = (Tokens.Layouts.AuthPhoneLayoutCountryCode.flagHeight / 4).sp),
            maxLines = 1,
            modifier = Modifier.size(CountryFlagSlot.width, CountryFlagSlot.height),
        )
    }
}

/**
 * The country list (`auth.phone.layout.countryCode` flagTap: "ours: the platform picker in a sheet"):
 * an M3 modal bottom sheet of M3 list rows — flag, the platform's country name, trailing "+code" —
 * scrolled to the current country; choosing one replaces the calling code.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CountryPickerSheet(selected: String?, onPick: (String) -> Unit, onDismiss: () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(),
        containerColor = Tokens.Colors.globalSystemSurfaceContainerLow,
    ) {
        CountryList(selected, onPick, Modifier.navigationBarsPadding())
    }
}

/** The sheet's list: one M3 row per country, starting at [selected]. */
@Composable
fun CountryList(selected: String?, onPick: (String) -> Unit, modifier: Modifier = Modifier) {
    val countries = remember { Countries.all() }
    val start = remember(selected) { countries.indexOfFirst { it.region == selected }.coerceAtLeast(0) }
    val list = rememberLazyListState(initialFirstVisibleItemIndex = start)
    LazyColumn(modifier.fillMaxWidth(), state = list) {
        items(countries, key = { it.region }) { country ->
            SystemRow(
                headline = country.name,
                leading = { Text(Countries.flag(country.region), style = MaterialTheme.typography.titleLarge) },
                trailing = { Text(PLUS + country.code, style = MaterialTheme.typography.bodyMedium, color = Tokens.Colors.globalSystemOnSurfaceVariant) },
                onClick = { onPick(country.region) },
                modifier = if (country.region == selected) Modifier.semantics { this.selected = true } else Modifier,
            )
        }
    }
}

private const val PLUS = "+"
