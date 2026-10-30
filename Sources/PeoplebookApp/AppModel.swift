import Foundation
import Observation
import PeoplebookKit

/// 界面状态与数据流。所有数据改动都经由本类写入 Repository 后回读。
@MainActor
@Observable
final class AppModel {
    let repository: Repository
    private(set) var contacts: [Contact] = []
    private(set) var interactions: [Interaction] = []
    private(set) var relationships: [Relationship] = []
    private(set) var loadErrorMessage: String?

    var selection: Contact.ID?
    var query: String = ""

    var importing = false

    /// 仅测试与 SwiftUI 预览使用内存库。
    init(repository: Repository) {
        self.repository = repository
        reload()
        bootstrapIfEmpty()
    }

    static func make() -> AppModel {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Peoplebook", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("peoplebook.sqlite3").path
        let repository = (try? Repository(path: path)) ?? (try! Repository(path: ":memory:"))
        return AppModel(repository: repository)
    }

    static func makeInMemory() -> AppModel {
        AppModel(repository: try! Repository(path: ":memory:"))
    }

    // MARK: - 装载

    func reload() {
        do {
            contacts = try repository.allContacts()
            interactions = try repository.allInteractions()
            relationships = try repository.relationships()
        } catch {
            loadErrorMessage = String(describing: error)
        }
    }

    /// 空库时种入假数据（首轮 6 人）。
    private func bootstrapIfEmpty() {
        guard contacts.isEmpty else { return }
        let seed = MockData.seed()
        for contact in seed.contacts { try? repository.saveContact(contact) }
        for interaction in seed.interactions { try? repository.saveInteraction(interaction) }
        for relationship in seed.relationships { try? repository.saveRelationship(relationship) }
        reload()
    }

    // MARK: - 派生

    var searchResults: [SearchResult] {
        ContactSearch.search(contacts: contacts, interactions: interactions, query: query)
    }

    var selectedContact: Contact? {
        contacts.first { $0.id == selection }
    }

    func interactions(of contactID: UUID) -> [Interaction] {
        interactions.filter { $0.contactID == contactID }
            .sorted { $0.date > $1.date }
    }

    func relationships(of contactID: UUID) -> [Relationship] {
        relationships.filter { $0.firstContactID == contactID || $0.secondContactID == contactID }
    }

    func contact(id: UUID) -> Contact? {
        contacts.first { $0.id == id }
    }

    func isOverdue(_ contact: Contact) -> Bool {
        let last = Reminder.lastInteractionDate(interactions(of: contact.id))
        return Reminder.isOverdue(
            contact: contact, lastInteraction: last, now: Date()
        )
    }

    // MARK: - 修改

    func saveContact(_ contact: Contact) {
        try? repository.saveContact(contact)
        reload()
    }

    func addContact(_ contact: Contact) {
        try? repository.saveContact(contact)
        selection = contact.id
        reload()
    }

    func deleteContact(_ contact: Contact) {
        try? repository.deleteContact(id: contact.id)
        if selection == contact.id { selection = nil }
        reload()
    }

    func addInteraction(_ interaction: Interaction) {
        try? repository.saveInteraction(interaction)
        reload()
    }

    func deleteInteraction(_ interaction: Interaction) {
        try? repository.deleteInteraction(id: interaction.id)
        reload()
    }

    func addRelationship(first: UUID, second: UUID, kind: RelationshipKind) {
        guard first != second else { return }
        try? repository.saveRelationship(
            Relationship(firstContactID: first, secondContactID: second, kind: kind)
        )
        reload()
    }

    func deleteRelationship(_ relationship: Relationship) {
        try? repository.deleteRelationship(id: relationship.id)
        reload()
    }

    /// 把预览中被勾选导入的候选创建为联系人。
    func importCandidates(_ candidates: [CSVImporter.Candidate]) {
        for candidate in candidates where !candidate.skip {
            let contact = candidate.makeContact()
            try? repository.saveContact(contact)
        }
        reload()
    }
}
