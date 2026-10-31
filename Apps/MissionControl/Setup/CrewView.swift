import ContactsUI
import MissionCore
import SwiftData
import SwiftUI

/// The people to ring once the unit knows what's happening, in the order he'll want them.
struct CrewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \CrewContact.sortOrder) private var crew: [CrewContact]
    @State private var editing: CrewContact?
    @State private var pickingContact = false

    var body: some View {
        List {
            Section {
                ForEach(crew) { person in
                    Button {
                        editing = person
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name.isEmpty ? "No name" : person.name).foregroundStyle(.primary)
                            Text([person.role.title, person.phone].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        context.delete(crew[index])
                    }
                    model.savePlanning()
                }
                .onMove { source, destination in
                    var ordered = crew
                    ordered.move(fromOffsets: source, toOffset: destination)
                    for (index, person) in ordered.enumerated() {
                        person.sortOrder = index
                    }
                    model.savePlanning()
                }
            } footer: {
                Text(
                    "The unit always comes first. These are for after: who's driving, who has the children, who "
                        + "to tell. They're on the Call tab, below the unit."
                )
            }
            Section {
                Button {
                    pickingContact = true
                } label: {
                    Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
                }
                Button {
                    editing = add(name: "", phone: "")
                } label: {
                    Label("Add by hand", systemImage: "plus")
                }
            } footer: {
                Text("Only the name and the number you pick are copied in.")
            }
        }
        .navigationTitle("People to call")
        .toolbar {
            if !crew.isEmpty {
                EditButton()
            }
        }
        .sheet(item: $editing, onDismiss: tidy) { person in
            NavigationStack {
                CrewContactForm(person: person)
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

    /// Drops anyone left with no name and no number, then saves.
    private func tidy() {
        for person in crew where person.name.isEmpty && person.phone.isEmpty {
            context.delete(person)
        }
        model.savePlanning()
    }
}

private struct CrewContactForm: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Bindable var person: CrewContact

    var body: some View {
        Form {
            TextField("Name", text: $person.name)
                .textContentType(.name)
            Picker("Role", selection: $person.role) {
                ForEach(CrewRole.allCases) { role in
                    Text(role.title).tag(role)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                FieldLabel("Phone", isShown: !person.phone.isEmpty)
                TextField("Phone", text: $person.phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                NumberCheck(result: person.phoneCheck(region: model.profile.region), isPerson: true)
            }
            TextField("Note, like “has the spare key”", text: $person.note, axis: .vertical)
        }
        .navigationTitle(person.name.isEmpty ? "New person" : person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
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
