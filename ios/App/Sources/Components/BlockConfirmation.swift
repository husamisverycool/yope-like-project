// Shared component — the block confirmation (`safety.block`), for every surface that offers "Block".
import DesignSystem
import SwiftUI

/// Who is being blocked.
struct BlockTarget: Identifiable, Hashable {
    /// The person's user id (`block_user(p_user_id)`).
    let userID: String
    /// First name shown in the title, message and toast (`{first_name}`).
    let firstName: String

    var id: String { userID }
}

extension View {
    /// Presents the block confirmation for `target` (`safety.block.layout.confirm`: `confirmationDialog` with a visible
    /// title `safety.block.title`, message `safety.block.message`, destructive `safety.block.confirm`, and
    /// `safety.block.cancel` at the bottom).
    ///
    /// `perform` runs `block_user` (e.g. `SafetyRepository.block(userID:)`). While it runs the dialog's place shows the
    /// platform progress indicator; on failure the dialog comes back with its message replaced by
    /// `safety.block.error` and `haptic.global.error` plays. On success `haptic.global.warning` plays, the toast
    /// `safety.block.done` is shown through `toasts` (release builds: announcement only, see `ToastCenter`) and
    /// `onBlocked` runs so the screen can refetch (the person's content disappears through RLS).
    func blockConfirmation(
        target: Binding<BlockTarget?>,
        toasts: ToastCenter,
        perform: @escaping @MainActor (BlockTarget) async throws -> Void,
        onBlocked: @escaping @MainActor (BlockTarget) -> Void = { _ in }
    ) -> some View {
        modifier(BlockConfirmationModifier(target: target, toasts: toasts, perform: perform, onBlocked: onBlocked))
    }
}

private struct BlockConfirmationModifier: ViewModifier {
    @Binding var target: BlockTarget?
    let toasts: ToastCenter
    let perform: @MainActor (BlockTarget) async throws -> Void
    let onBlocked: @MainActor (BlockTarget) -> Void

    @State private var isBlocking = false
    @State private var failed = false
    @State private var warningTrigger = 0
    @State private var errorTrigger = 0

    private var isPresented: Binding<Bool> {
        Binding(
            get: { target != nil && !isBlocking },
            set: { presented in
                if !presented, !isBlocking {
                    target = nil
                    failed = false
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                Text(target.map { Copy.safetyBlockTitle(firstName: $0.firstName) } ?? ""),
                isPresented: isPresented,
                titleVisibility: .visible,
                presenting: target
            ) { target in
                Button(Copy.safetyBlockConfirm, role: .destructive) {
                    block(target)
                }
                Button(Copy.safetyBlockCancel, role: .cancel) {
                    self.target = nil
                    failed = false
                }
            } message: { target in
                Text(failed ? Copy.safetyBlockError : Copy.safetyBlockMessage(firstName: target.firstName))
            }
            .blockProgress(isBlocking)
            .dsHaptic(Tokens.Haptics.globalWarning, trigger: warningTrigger)
            .dsHaptic(Tokens.Haptics.globalError, trigger: errorTrigger)
    }

    private func block(_ blocked: BlockTarget) {
        isBlocking = true
        Task { @MainActor in
            do {
                try await perform(blocked)
                isBlocking = false
                failed = false
                target = nil
                warningTrigger += 1
                toasts.show(Copy.safetyBlockDone(firstName: blocked.firstName))
                onBlocked(blocked)
            } catch {
                failed = true
                isBlocking = false
                errorTrigger += 1
            }
        }
    }
}

private extension View {
    /// The platform progress indicator over the view while the block request runs ("the dialog's confirm shows
    /// native progress": a confirmation dialog cannot host one, so it is shown centred where the dialog was).
    func blockProgress(_ isActive: Bool) -> some View {
        overlay {
            if isActive {
                ProgressView()
            }
        }
    }
}
