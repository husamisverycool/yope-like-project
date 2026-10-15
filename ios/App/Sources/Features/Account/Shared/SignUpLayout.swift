// Account group — the Yope sign-up / onboarding form stack shared by auth.phone, auth.code, auth.agegate,
// auth.profile (references S24, S26, C24, BI): black screen, centred title block, field, lime button, all
// top-aligned and directly above the system keyboard.
import DesignSystem
import SwiftUI

/// Scrollable sign-up stack on `color.global.backgroundDeep`.
///
/// - `header`: optional leading header circle row at the safe-area top, inset `size.global.headerInset`.
/// - `content`: title block first, placed `groups.create.size.sheetTopToTitle` below the safe-area top (the frame
///   top stands in for the cap top; approximation, auth.phone Gaps), then the form elements with their own gaps.
/// - `footer`: pinned to the bottom above the home indicator while there is room; when the keyboard is up it moves up
///   with the stack and sits under the content (auth.phone item 9).
/// The stack scrolls when it no longer fits above the keyboard (large Dynamic Type sizes).
struct SignUpLayout<Header: View, Content: View, Footer: View>: View {
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    init(
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.header = header
        self.content = content
        self.footer = footer
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    content()
                        .padding(.top, Tokens.Sizes.groupsCreateSizeSheetTopToTitle)
                    Spacer(minLength: 0)
                    footer()
                }
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.never)
        }
        .overlay(alignment: .topLeading) {
            header()
                .padding(.leading, Tokens.Sizes.globalHeaderInset)
        }
        .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

extension SignUpLayout where Header == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder footer: @escaping () -> Footer) {
        self.init(header: { EmptyView() }, content: content, footer: footer)
    }
}

extension SignUpLayout where Header == EmptyView, Footer == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.init(header: { EmptyView() }, content: content, footer: { EmptyView() })
    }
}

/// The offline / refusal / not-open states of the sign-up steps: Yope's empty-state layout replacing the form,
/// centred on the black screen (auth.phone "offline").
struct SignUpStateView: View {
    let title: String?
    let detail: String?
    var retry: EmptyStateView.Action?

    var body: some View {
        EmptyStateView(title: title, detail: detail, action: retry)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Colors.globalBackgroundDeep.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
    }
}
