package app.feature.account.auth

import com.google.i18n.phonenumbers.NumberParseException
import com.google.i18n.phonenumbers.PhoneNumberUtil

/**
 * auth.phone field rules (`auth.phone.layout.countryCode`): pre-filled with "+" and the device region's
 * calling code; the calling code is typed inline with the number and the flag follows it; formatted as
 * it is typed (autoFormat); a zero after the calling code is kept (allowZeroAfterCountryCode);
 * normalised to E.164 before sending (libphonenumber).
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

    /** The calling code at the start of [text] ("+44 20…" → 44): the longest 1–3 digit prefix that is assigned. */
    fun callingCode(text: String): Int? {
        if (!text.trimStart().startsWith("+")) return null
        val d = digits(text)
        for (len in minOf(MAX_CODE_DIGITS, d.length) downTo 1) {
            val code = d.substring(0, len).toInt()
            if (util.getRegionCodeForCountryCode(code) != UNKNOWN_REGION) return code
        }
        return null
    }

    /**
     * The region whose flag the field shows: the region of the full number when libphonenumber can tell
     * (+1 415… → US, +1 416… → CA); else [preferred] (the device region, or the last country picked)
     * when it shares the calling code; else the code's main region; null without a calling code.
     */
    fun regionFor(text: String, preferred: String?): String? {
        val code = callingCode(text) ?: return null
        val parsed = try {
            util.parse(text.trim(), UNKNOWN_REGION)
        } catch (_: NumberParseException) {
            null
        }
        // Null until the digits identify one region (a valid number).
        val byNumber = parsed?.let(util::getRegionCodeForNumber)
        if (byNumber != null && byNumber != UNKNOWN_REGION) return byNumber
        val pref = preferred?.uppercase()
        if (pref != null && util.getCountryCodeForRegion(pref) == code) return pref
        return util.getRegionCodeForCountryCode(code).takeIf { it != UNKNOWN_REGION }
    }

    /** [text] with its calling code replaced by [region]'s ("choosing a country replaces the calling code"). */
    fun withRegion(text: String, region: String): String {
        val newCode = util.getCountryCodeForRegion(region.uppercase())
        val national = callingCode(text)?.let { digits(text).drop(it.toString().length) } ?: digits(text)
        return format("+$newCode$national")
    }

    /** As-you-type formatting of [text] ("+14155550100" → "+1 415-555-0100"); text without "+" is left as typed. */
    fun format(text: String): String {
        val clean = sanitize(text)
        if (!clean.startsWith("+")) return clean
        val formatter = util.getAsYouTypeFormatter(UNKNOWN_REGION)
        var out = "+"
        formatter.inputDigit('+')
        digits(clean).forEach { out = formatter.inputDigit(it) }
        return out
    }

    /**
     * The field's next value after an edit from [old] to [new]: formatted; deleting only a separator
     * (space, dash) deletes the digit before it, so backspace never stalls on formatting.
     */
    fun edit(old: String, new: String): String {
        val separatorOnly = new.length < old.length && digits(new) == digits(old) && new.startsWith("+") == old.startsWith("+")
        val next = if (separatorOnly) {
            val d = digits(new)
            (if (new.startsWith("+")) "+" else "") + d.dropLast(1)
        } else {
            new
        }
        return format(next)
    }

    /** Keeps "+" (first character only) and digits. */
    fun sanitize(text: String): String {
        val sb = StringBuilder()
        text.forEachIndexed { i, c -> if (c.isDigit() || (c == '+' && i == 0) || c == ' ' || c == '-' || c == '(' || c == ')') sb.append(c) }
        return sb.toString()
    }

    private fun digits(s: String) = s.filter(Char::isDigit)

    private const val UNKNOWN_REGION = "ZZ"
    private const val MAX_CODE_DIGITS = 3
}
