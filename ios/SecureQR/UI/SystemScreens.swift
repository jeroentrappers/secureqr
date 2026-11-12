import Contacts
import ContactsUI
import EventKit
import EventKitUI
import SwiftUI

/// Builds the contact that the system's new-contact screen starts from.
/// Nothing is read from or written to the address book here.
enum ContactDraft {
    static func contact(for payload: ScannedPayload) -> CNContact {
        guard case .contact(let card) = payload.content else { return CNContact() }
        // A vCard is read by the system itself, so nothing in it is lost.
        if QRText.hasPrefix(payload.raw, "begin:vcard"),
           let contacts = try? CNContactVCardSerialization.contacts(with: Data(payload.raw.utf8)),
           let contact = contacts.first {
            return contact
        }
        return contact(from: card)
    }

    static func contact(from card: ContactCard) -> CNContact {
        let contact = CNMutableContact()
        // The last word is taken for the family name.
        let words = card.name.split(separator: " ").map { String($0) }
        if words.count > 1 {
            contact.givenName = words.dropLast().joined(separator: " ")
            contact.familyName = words[words.count - 1]
        } else {
            contact.givenName = card.name
        }
        contact.organizationName = card.organisation
        contact.phoneNumbers = card.phones.map {
            CNLabeledValue(label: nil, value: CNPhoneNumber(stringValue: $0))
        }
        contact.emailAddresses = card.emails.map {
            CNLabeledValue(label: nil, value: $0 as NSString)
        }
        if !card.address.isEmpty {
            let address = CNMutablePostalAddress()
            address.street = card.address
            contact.postalAddresses = [CNLabeledValue(label: nil, value: address)]
        }
        if !card.url.isEmpty {
            contact.urlAddresses = [CNLabeledValue(label: nil, value: card.url as NSString)]
        }
        return contact
    }
}

/// The system's new-contact screen, filled in. The user saves or cancels
/// there; the app itself has no access to the contacts.
struct NewContactScreen: UIViewControllerRepresentable {
    let contact: CNContact
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator {
        return Coordinator(onDone: onDone)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let controller = CNContactViewController(forNewContact: contact)
        controller.delegate = context.coordinator
        return UINavigationController(rootViewController: controller)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        private let onDone: () -> Void

        init(onDone: @escaping () -> Void) {
            self.onDone = onDone
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            onDone()
        }
    }
}

/// The system's new-event screen, filled in. From iOS 17 it runs outside the
/// app and needs no calendar access; the user saves or cancels there.
@available(iOS 17.0, *)
struct NewEventScreen: UIViewControllerRepresentable {
    let event: CalendarEvent
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator {
        return Coordinator(onDone: onDone)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let item = EKEvent(eventStore: store)
        item.title = event.title
        if let schedule = event.schedule {
            item.startDate = schedule.start
            item.endDate = schedule.end
            item.isAllDay = schedule.isAllDay
        }
        if !event.location.isEmpty {
            item.location = event.location
        }
        if !event.details.isEmpty {
            item.notes = event.details
        }
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = item
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        private let onDone: () -> Void

        init(onDone: @escaping () -> Void) {
            self.onDone = onDone
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }
    }
}
