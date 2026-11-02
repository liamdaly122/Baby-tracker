import ContactsUI
import MissionCore
import MissionUI
import SwiftData
import SwiftUI

/// The people to ring once the unit knows what's happening, in the order he'll want them: the
/// prototype's crew rows, each with its own call button.
struct CrewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \CrewContact.sortOrder) private var crew: [CrewContact]
    @State private var editing: CrewContact?
    /// "Remove" was tapped: they're deleted once the form has closed, not while it shows them.
    @State private var removing: CrewContact?
    @State private var pickingContact = false

    var body: some View {
        PaperPage("People to call", subtitle: "Who to tell, and when") {
            PaperSection(
                "The crew",
                note: "The unit always comes first. These are for after: who's driving, who has the children, who to "
                    + "tell. They're on the Call tab, below the unit."
            ) {
                ForEach(Array(crew.enumerated()), id: \.element.id) { index, person in
                    CrewRow(person: person, region: model.profile.region, canMoveUp: index > 0) {
                        editing = person
                    } moveUp: {
                        move(person, from: index)
                    }
                }
                Button {
                    pickingContact = true
                } label: {
                    Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(PaperButtonStyle(.solid))
                Button {
                    editing = add(name: "", phone: "")
                } label: {
                    Text("+ Add someone by hand")
                }
                .buttonStyle(PaperButtonStyle(.ghost))
                PaperNote("Only the name and the number you pick are copied in.")
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing, onDismiss: tidy) { person in
            NavigationStack {
                CrewContactForm(person: person) {
                    removing = person
                    editing = nil
                }
            }
        }
        .background(
            ContactPicker(isPresented: $pickingContact) { name, phone in
                editing = add(name: name, phone: phone)
            }
        )
    }

    @discardableResult
    private func add(name: String, phone: String) -> CrewContact {
        let person = CrewContact(name: name, phone: phone, sortOrder: (crew.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(person)
        return person
    }

    /// One place up the list.
    private func move(_ person: CrewContact, from index: Int) {
        var ordered = crew
        ordered.swapAt(index, index - 1)
        for (position, member) in ordered.enumerated() {
            member.sortOrder = position
        }
        model.savePlanning()
    }

    /// Drops anyone removed, or left with no name and no number, then saves.
    private func tidy() {
        if let removing {
            context.delete(removing)
            self.removing = nil
        }
        for person in crew where person.name.isEmpty && person.phone.isEmpty {
            context.delete(person)
        }
        model.savePlanning()
    }
}

/// One person: their initial, name, role, number, and Call, Edit and "move up".
private struct CrewRow: View {
    @Environment(\.colorScheme) private var scheme
    var person: CrewContact
    var region: ContentRegion
    var canMoveUp: Bool
    var edit: () -> Void
    var moveUp: () -> Void

    var body: some View {
        let colours = PaperColors.for(scheme)
        let name = person.name.isEmpty ? "No name" : person.name
        PaperCard {
            HStack(alignment: .top, spacing: 10) {
                Text(String(name.prefix(1)).uppercased())
                    .font(MissionType.display(22, relativeTo: .title3))
                    .foregroundStyle(colours.onSolid)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(colours.solid))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(MissionType.body(16).weight(.bold))
                    Text([person.role.title, person.note].filter { !$0.isEmpty }.joined(separator: " · ").uppercased())
                        .font(MissionType.mono())
                        .foregroundStyle(colours.muted)
                    if !person.phone.isEmpty {
                        NumberCheck(result: person.phoneCheck(region: region), isPerson: true)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                if case .success(let number) = person.phoneCheck(region: region), let url = number.telURL {
                    Link(destination: url) {
                        Label("Call", systemImage: "phone.fill")
                    }
                    .buttonStyle(PaperButtonStyle(.solid))
                    .accessibilityLabel("Call \(name)")
                }
                Button("Edit", action: edit)
                    .buttonStyle(PaperButtonStyle(.ghost))
                    .accessibilityLabel("Edit \(name)")
                if canMoveUp {
                    Button(action: moveUp) {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(PaperButtonStyle(.ghost))
                    .accessibilityLabel("Move \(name) up the list")
                }
            }
            // Compact, as the prototype's are, rather than across the card.
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private struct CrewContactForm: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Bindable var person: CrewContact
    var remove: () -> Void

    var body: some View {
        PaperPage(person.name.isEmpty ? "New person" : person.name, subtitle: "Someone to ring after the unit") {
            PaperField("Name") {
                TextField("", text: $person.name)
                    .textContentType(.name)
            }
            PaperLabel("Role")
            PaperChips(CrewRole.allCases, title: \.title, isPicked: { $0 == person.role }, pick: { person.role = $0 })
            VStack(alignment: .leading, spacing: 5) {
                PaperField("Phone") {
                    TextField("", text: $person.phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                NumberCheck(result: person.phoneCheck(region: model.profile.region), isPerson: true)
            }
            PaperField("Note, like “has the spare key”") {
                TextField("", text: $person.note, axis: .vertical)
            }
            Button("Done") { dismiss() }
                .buttonStyle(PaperButtonStyle(.solid))
                .padding(.top, 6)
            Button("Remove from the list", action: remove)
                .buttonStyle(PaperButtonStyle(.danger))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The system contact picker. It needs no permission to read Contacts: he picks one number, and
/// only the name and that number come back.
private struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onPick: (_ name: String, _ phone: String) -> Void

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        // One number: pick the person. More than one: he picks which number.
        picker.predicateForSelectionOfContact = NSPredicate(format: "phoneNumbers.@count == 1")
        Task { @MainActor in host.present(picker, animated: true) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, @MainActor CNContactPickerDelegate {
        var parent: ContactPicker

        init(parent: ContactPicker) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            finish(contact, phone: contact.phoneNumbers.first?.value.stringValue ?? "")
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contactProperty: CNContactProperty) {
            finish(contactProperty.contact, phone: (contactProperty.value as? CNPhoneNumber)?.stringValue ?? "")
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }

        private func finish(_ contact: CNContact, phone: String) {
            parent.isPresented = false
            let name = CNContactFormatter.string(from: contact, style: .fullName) ?? contact.givenName
            parent.onPick(name, phone)
        }
    }
}
