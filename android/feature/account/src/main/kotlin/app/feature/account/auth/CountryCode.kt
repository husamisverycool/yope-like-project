package app.feature.account.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.designsystem.generated.Tokens
import app.ui.foundation.PageRoles
import app.ui.foundation.tapClickable
import app.ui.system.DsBottomSheet
import app.ui.text.TextRoles
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
            // The touch target may overhang the field (it is taller than size.global.fieldHeight).
            .requiredSize(CountryFlagSlot.touchTarget)
            .tapClickable(onClick = onClick)
            .semantics { contentDescription = name },
        contentAlignment = Alignment.Center,
    ) {
        BasicText(
            Countries.flag(region),
            // Line box = font size, trimmed, so the emoji (not its line spacing) is what fits the slot.
            style = TextStyle(lineHeight = 1.em, lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.Both), textAlign = TextAlign.Center),
            autoSize = TextAutoSize.StepBased(minFontSize = (Tokens.Layouts.AuthPhoneLayoutCountryCode.flagHeight / 4).sp),
            maxLines = 1,
            modifier = Modifier.size(CountryFlagSlot.width, CountryFlagSlot.height),
        )
    }
}

/**
 * The country list (`auth.phone.layout.countryCode` flagTap: "opens a country list in a native sheet (C-29)"): the C-29 page
 * sheet ([DsBottomSheet], expanded) holding the list, scrolled to the current country; choosing one replaces the calling code.
 */
@Composable
fun CountryPickerSheet(selected: String?, onPick: (String) -> Unit, onDismiss: () -> Unit) {
    DsBottomSheet(onDismissRequest = onDismiss) {
        CountryList(selected, onPick, Modifier.navigationBarsPadding())
    }
}

/**
 * The sheet's list: one row per country — the flag in the C-12 flag slot, the platform's country name (text role `body`,
 * `color.global.textPrimary`) and the trailing "+code" (text role `body`, secondary text), as the C-14 row lays out a
 * title and its trailing value; `size.global.screenMargin` padding, at least `size.global.minTouchTarget.android` high.
 * The current country carries the selected state; a row press plays `haptic.global.tap` (the choice plays
 * `haptic.global.select` in the view model).
 */
@Composable
fun CountryList(selected: String?, onPick: (String) -> Unit, modifier: Modifier = Modifier) {
    val countries = remember { Countries.all() }
    val start = remember(selected) { countries.indexOfFirst { it.region == selected }.coerceAtLeast(0) }
    val list = rememberLazyListState(initialFirstVisibleItemIndex = start)
    val margin = Tokens.Sizes.globalScreenMargin
    val secondary = PageRoles.secondaryText()
    LazyColumn(modifier.fillMaxWidth(), state = list) {
        items(countries, key = { it.region }) { country ->
            Row(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = Tokens.Sizes.globalMinTouchTargetAndroid)
                    .tapClickable { onPick(country.region) }
                    .semantics(mergeDescendants = true) { if (country.region == selected) this.selected = true }
                    .padding(horizontal = margin),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Tokens.Sizes.globalCardNameGap),
            ) {
                FlagText(country.region)
                Text(country.name, style = TextRoles.body, color = Tokens.Colors.globalTextPrimary, modifier = Modifier.weight(1f))
                Text(PLUS + country.code, style = TextRoles.body, color = secondary)
            }
        }
    }
}

/** The flag emoji fitted into the C-12 flag slot (`auth.phone.layout.countryCode` flagWidth × flagHeight). */
@Composable
private fun FlagText(region: String) {
    BasicText(
        Countries.flag(region),
        style = TextStyle(lineHeight = 1.em, lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.Both), textAlign = TextAlign.Center),
        autoSize = TextAutoSize.StepBased(minFontSize = (Tokens.Layouts.AuthPhoneLayoutCountryCode.flagHeight / 4).sp),
        maxLines = 1,
        modifier = Modifier.size(CountryFlagSlot.width, CountryFlagSlot.height).clearAndSetSemantics { },
    )
}

private const val PLUS = "+"
