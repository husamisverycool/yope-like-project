// Account group — the signed-in person's phone number for settings.account (read-only row). App target only:
// the App Clip does not show it and does not link Supabase directly.
import Supabase

extension LiveAccountData {
    /// The phone number of the stored session's user (E.164 without "+", as Supabase Auth stores it), if any.
    var currentPhone: String? {
        guard let phone = environment?.client.supabase.auth.currentUser?.phone, !phone.isEmpty else { return nil }
        return phone.hasPrefix("+") ? phone : "+" + phone
    }
}
