import Foundation
import Testing
import PeoplebookKit

/// 接缝 3：SQLite 落盘保存 / 更新 / 级联删除（spec「Testing Decisions」#3）。
struct RepositoryTests {
    /// 每个测试一把独立的临时文件库。
    private func makeRepository() throws -> Repository {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peoplebook-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return try Repository(path: dir.appendingPathComponent("peoplebook.sqlite3").path)
    }

    @Test("联系人落盘往返")
    func contactRoundtrip() throws {
        let repository = try makeRepository()
        let original = Contact(
            name: "陈志远",
            phone: "13800000001",
            email: "a@example.com",
            company: "云帆科技",
            title: "技术合伙人",
            note: "老搭档",
            level: .key,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try repository.saveContact(original)
        let loaded = try repository.contact(id: original.id)
        #expect(loaded == original)
        #expect(try repository.allContacts() == [original])
    }

    @Test("联系人更新（upsert）")
    func contactUpdate() throws {
        let repository = try makeRepository()
        var contact = Contact(name: "王芳", level: .normal)
        try repository.saveContact(contact)
        contact.level = .key
        contact.note = "改备注"
        try repository.saveContact(contact)
        #expect(try repository.allContacts().count == 1)
        let reloaded = try repository.contact(id: contact.id)
        #expect(reloaded == contact)
    }

    @Test("查不到的联系人抛 notFound")
    func missingContactThrows() throws {
        let repository = try makeRepository()
        #expect(throws: Repository.RepositoryError.notFound) {
            try repository.contact(id: UUID())
        }
    }

    @Test("互动落盘往返且按日期倒序")
    func interactionRoundtripAndOrder() throws {
        let repository = try makeRepository()
        let contact = Contact(name: "王芳")
        try repository.saveContact(contact)

        let older = Interaction(contactID: contact.id, kind: .email, date: Date(timeIntervalSince1970: 100), note: "旧")
        let newer = Interaction(contactID: contact.id, kind: .meeting, date: Date(timeIntervalSince1970: 200), note: "新")
        try repository.saveInteraction(older)
        try repository.saveInteraction(newer)

        let loaded = try repository.interactions(forContact: contact.id)
        #expect(loaded == [newer, older])

        // 更新笔记
        var updated = older
        updated.note = "改过的旧互动"
        try repository.saveInteraction(updated)
        #expect(try repository.interactions(forContact: contact.id).first { $0.id == older.id }?.note == "改过的旧互动")

        try repository.deleteInteraction(id: older.id)
        #expect(try repository.interactions(forContact: contact.id) == [newer])
    }

    @Test("关系落盘往返，两端都可查")
    func relationshipRoundtrip() throws {
        let repository = try makeRepository()
        let a = Contact(name: "陈志远")
        let b = Contact(name: "王芳")
        try repository.saveContact(a)
        try repository.saveContact(b)

        let edge = Relationship(firstContactID: a.id, secondContactID: b.id, kind: .introducedVia)
        try repository.saveRelationship(edge)

        #expect(try repository.relationships() == [edge])
        #expect(try repository.relationships(forContact: a.id) == [edge])
        #expect(try repository.relationships(forContact: b.id) == [edge])
        try repository.deleteRelationship(id: edge.id)
        #expect(try repository.relationships().isEmpty)
    }

    @Test("删除联系人级联清除互动与关系边")
    func cascadeDelete() throws {
        let repository = try makeRepository()
        let a = Contact(name: "陈志远", level: .key)
        let b = Contact(name: "王芳")
        try repository.saveContact(a)
        try repository.saveContact(b)

        try repository.saveInteraction(
            Interaction(contactID: a.id, kind: .wechat, date: Date(), note: "聊")
        )
        try repository.saveRelationship(
            Relationship(firstContactID: a.id, secondContactID: b.id, kind: .colleague)
        )

        try repository.deleteContact(id: a.id)

        let remaining = try repository.allContacts()
        #expect(remaining == [b])
        #expect(try repository.allInteractions().isEmpty)
        #expect(try repository.relationships().isEmpty)
    }
}
