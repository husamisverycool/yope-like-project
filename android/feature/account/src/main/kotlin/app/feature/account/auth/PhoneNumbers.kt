package app.feature.account.auth

import com.google.i18n.phonenumbers.NumberParseException
import com.google.i18n.phonenumbers.PhoneNumberUtil

/**
 * auth.phone field rules: pre-filled with "+" and the device region's calling code; edited as text;
 * normalised to E.164 before sending (libphonenumber; the country-code selector is BLOCKED,
 * `auth.phone.layout.countryCode`).
 */
object PhoneNumbers {
    private val util: PhoneNumberUtil by lazy { PhoneNumberUtil.getInstance() }

    /** "+" and the calling code of [region] (ISO 3166 alpha-2), or "+" when unknown. */
    fun prefill(region: String?): String {
        val code = region?.uppercase()?.let { util.getCountryCodeForRegion(it) } ?: 0
        return if (code > 0) "+$code" else "+"
    }

    /** Continue is enabled once the field holds digits after the calling code. */
    fun hasDigitsAfterPrefix(text: String, prefill: String): Boolean = digits(text).length > digits(prefill).length

    /** The E.164 form, or null when the text is not a valid number. */
    fun toE164(text: String, region: String?): String? = try {
        val parsed = util.parse(text.trim(), region?.uppercase() ?: "ZZ")
        if (util.isValidNumber(parsed)) util.format(parsed, PhoneNumberUtil.PhoneNumberFormat.E164) else null
    } catch (_: NumberParseException) {
        null
    }

    /** The number formatted for display ("{phone} = the number as entered, formatted for display"). */
    fun display(e164: String): String = try {
        util.format(util.parse(e164, "ZZ"), PhoneNumberUtil.PhoneNumberFormat.INTERNATIONAL)
    } catch (_: NumberParseException) {
        e164
    }

    /** Keeps "+" (first character only) and digits. */
    fun sanitize(text: String): String {
        val sb = StringBuilder()
        text.forEachIndexed { i, c -> if (c.isDigit() || (c == '+' && i == 0) || c == ' ' || c == '-' || c == '(' || c == ')') sb.append(c) }
        return sb.toString()
    }

    private fun digits(s: String) = s.filter(Char::isDigit)
}
