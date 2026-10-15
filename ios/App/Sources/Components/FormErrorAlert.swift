// Shared component — how a form error is presented on the sign-up screens and the group form
// (`auth.phone.layout.inlineError`; auth.phone, auth.code, auth.agegate, auth.profile, groups.create, the App Clip's join
// sheet).
import DesignSystem
import SwiftUI

extension View {
    /// Presents `message` as a system alert each time `trigger` changes while `message` is non-nil
    /// (`auth.phone.layout.inlineError`): no title — the error sentence is the alert's message — and one button,
    /// `auth.phone.error.dismiss`, that closes it. A system alert is not dismissed by tapping outside.
    func formErrorAlert(_ message: String?, trigger: Int) -> some View {
        modifier(FormErrorAlert(message: message, trigger: trigger))
    }
}

private struct FormErrorAlert: ViewModifier {
    let message: String?
    let trigger: Int
    @State private var shown: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, _ in
                if let message { shown = message }
            }
            .alert(
                Text(verbatim: ""), // provenance-ok: no title (auth.phone.layout.inlineError: the sentence is the message)
                isPresented: Binding(get: { shown != nil }, set: { if !$0 { shown = nil } }),
                presenting: shown
            ) { _ in
                Button(Copy.authPhoneErrorDismiss, role: .cancel) {}
            } message: { text in
                Text(text)
            }
    }
}
