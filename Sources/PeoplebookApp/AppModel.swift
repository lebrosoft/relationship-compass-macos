import Foundation
import Observation
import PeoplebookKit

/// 界面状态与数据流。所有数据改动都经由本类写入 Repository 后回读；
/// 写路径错误不再静默吞掉（actionErrorMessage），启动降级有告警（persistenceWarning）。
@MainActor
@Observable
final class AppModel {
    let repository: Repository
    private(set) var contacts: [Contact] = []
    private(set) var interactions: [Interaction] = []
    private(set) var relationships: [Relationship] = []
    private(set) var loadErrorMessage: String?
    /// 写操作失败的用户可见信息，展示为一次性告警。
    private(set) var actionErrorMessage: String?
    /// 本地库打不开、本会话降级为内存库时向用户说明（ADR 0001：数据必须落盘）。
    private(set) var persistenceWarning: String?

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
        do {
            return AppModel(repository: try Repository(path: path))
        } catch {
            // 内存库几乎不可能打开失败；若真失败则环境本身不可用。
            let model = AppModel(repository: try! Repository(path: ":memory:"))
            model.persistenceWarning = """
            本地数据库（\(path)）无法打开：
            \(String(describing: error))

            本次会话数据只保存在内存中，退出后即丢失。
            """
            return model
        }
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
        perform {
            let seed = MockData.seed()
            for contact in seed.contacts { try repository.saveContact(contact) }
            for interaction in seed.interactions { try repository.saveInteraction(interaction) }
            for relationship in seed.relationships { try repository.saveRelationship(relationship) }
        }
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

    // MARK: - 修改（写错误经 perform 上浮为告警，不静默）

    private func perform(_ block: () throws -> Void) {
        do {
            try block()
        } catch {
            actionErrorMessage = "操作失败：\(String(describing: error))"
        }
        reload()
    }

    func clearActionError() {
        actionErrorMessage = nil
    }

    func clearPersistenceWarning() {
        persistenceWarning = nil
    }

    func saveContact(_ contact: Contact) {
        perform { try repository.saveContact(contact) }
    }

    func deleteContact(_ contact: Contact) {
        perform { try repository.deleteContact(id: contact.id) }
        if selection == contact.id { selection = nil }
    }

    func addInteraction(_ interaction: Interaction) {
        perform { try repository.saveInteraction(interaction) }
    }

    func deleteInteraction(_ interaction: Interaction) {
        perform { try repository.deleteInteraction(id: interaction.id) }
    }

    func addRelationship(first: UUID, second: UUID, kind: RelationshipKind) {
        perform {
            guard first != second else { return }
            try repository.saveRelationship(
                Relationship(firstContactID: first, secondContactID: second, kind: kind)
            )
        }
    }

    func deleteRelationship(_ relationship: Relationship) {
        perform { try repository.deleteRelationship(id: relationship.id) }
    }

    /// 把预览中被勾选导入的候选创建为联系人。
    func importCandidates(_ candidates: [CSVImporter.Candidate]) {
        perform {
            for candidate in candidates where !candidate.skip {
                try repository.saveContact(candidate.makeContact())
            }
        }
    }
}
