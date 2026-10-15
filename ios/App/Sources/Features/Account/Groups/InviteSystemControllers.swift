// Account group — system controllers used by groups.invite (all system UI, platform styling):
// share sheet (`groups.invite.layout.share`), contact picker (iOS 17 path of `groups.invite.layout.contacts`) and the SMS
// composer (`groups.invite.layout.contacts.send`: the person sees the invite before sending, App Review 5.1.2(v)).
import AppModels
import Contacts
import ContactsUI
import MessageUI
import SwiftUI
import UIKit

/// `UIActivityViewController` with the invite text (when available) and link.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// What the share sheet sends.
struct ShareRequest: Identifiable {
    let id = UUID()
    let items: [Any]
}

/// An SMS invite addressed to one number, shown in the system composer.
struct MessageRequest: Identifiable {
    let id = UUID()
    let recipient: String
    let body: String
    /// Row being invited (marked "invited" after `.sent`).
    let contactID: String
}

/// `MFMessageComposeViewController`; `onFinish(true)` when the message was sent.
struct MessageComposeView: UIViewControllerRepresentable {
    let request: MessageRequest
    let onFinish: (Bool) -> Void

    static var canSendText: Bool { MFMessageComposeViewController.canSendText() }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = [request.recipient]
        controller.body = request.body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    /// UIKit calls the delegate on the main thread; the conformance is main-actor isolated (`@preconcurrency` keeps it
    /// valid on SDKs where the protocol is not annotated yet).
    @MainActor
    final class Coordinator: NSObject, @preconcurrency MFMessageComposeViewControllerDelegate {
        let onFinish: (Bool) -> Void

        init(onFinish: @escaping (Bool) -> Void) {
            self.onFinish = onFinish
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            onFinish(result == .sent)
        }
    }
}

/// Presents `CNContactPickerViewController` (no contacts permission; one contact at a time) while `isPresented`.
/// The picker must be presented by UIKit, so this view hosts an invisible controller that presents it.
struct ContactPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: (LocalContact) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, !context.coordinator.isPresenting, host.presentedViewController == nil else { return }
        context.coordinator.isPresenting = true
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0") // provenance-ok: Contacts predicate, not user-facing
        // Presented on the next run-loop turn: UIKit cannot present during a SwiftUI view update.
        Task { @MainActor in host.present(picker, animated: true) }
    }

    /// UIKit calls the delegate on the main thread; the conformance is main-actor isolated (`@preconcurrency` keeps it
    /// valid on SDKs where the protocol is not annotated yet).
    @MainActor
    final class Coordinator: NSObject, @preconcurrency CNContactPickerDelegate {
        var parent: ContactPickerPresenter
        var isPresenting = false

        init(parent: ContactPickerPresenter) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let numbers = contact.phoneNumbers.compactMap { PhoneNumber($0.value.stringValue) }
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            isPresenting = false
            parent.isPresented = false
            if !numbers.isEmpty {
                parent.onPick(LocalContact(id: contact.identifier, displayName: name, phoneNumbers: numbers))
            }
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            isPresenting = false
            parent.isPresented = false
        }
    }
}

/// Contacts the person granted through `ContactAccessButton` (iOS 18 limited access), read by identifier.
enum GrantedContacts {
    static func contacts(withIdentifiers identifiers: [String]) async -> [LocalContact] {
        await Task.detached(priority: .userInitiated) {
            let store = CNContactStore()
            let keys: [CNKeyDescriptor] = [
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactPhoneNumbersKey as CNKeyDescriptor,
            ]
            let predicate = CNContact.predicateForContacts(withIdentifiers: identifiers)
            let found = (try? store.unifiedContacts(matching: predicate, keysToFetch: keys)) ?? []
            return found.compactMap { contact -> LocalContact? in
                let numbers = contact.phoneNumbers.compactMap { PhoneNumber($0.value.stringValue) }
                guard !numbers.isEmpty else { return nil }
                let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
                return LocalContact(id: contact.identifier, displayName: name, phoneNumbers: numbers)
            }
        }.value
    }
}
