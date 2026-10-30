import Foundation
import SQLite3
import Testing
import PeoplebookKit

/// 接缝 3：SQLite 落盘保存 / 更新 / 级联删除（spec「Testing Decisions」#3）。
struct RepositoryTests {
    /// 每个测试一把独立的临时文件库；返回 (库, 文件 URL)。
    private func makeRepository() throws -> (Repository, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("peoplebook-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = dir.appendingPathComponent("peoplebook.sqlite3")
        return try (Repository(path: fileURL.path), fileURL)
    }

    @Test("联系人落盘往返")
    func contactRoundtrip() throws {
        let (repository, _) = try makeRepository()
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
        let (repository, _) = try makeRepository()
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
        let (repository, _) = try makeRepository()
        #expect(throws: Repository.RepositoryError.notFound) {
            try repository.contact(id: UUID())
        }
    }

    @Test("互动落盘往返且按日期倒序")
    func interactionRoundtripAndOrder() throws {
        let (repository, _) = try makeRepository()
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
        let changed = try repository.interactions(forContact: contact.id)
        #expect(changed.first { $0.id == older.id }?.note == "改过的旧互动")

        try repository.deleteInteraction(id: older.id)
        #expect(try repository.interactions(forContact: contact.id) == [newer])
    }

    @Test("关系落盘往返，两端都可查")
    func relationshipRoundtrip() throws {
        let (repository, _) = try makeRepository()
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
        let (repository, _) = try makeRepository()
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

    @Test("损坏的枚举值 → 读取时抛错，不静默改类")
    func corruptedEnumThrows() throws {
        let (repository, fileURL) = try makeRepository()
        let contact = Contact(name: "李金陵", level: .key)
        try repository.saveContact(contact)

        // 第二条连接直改底层，制造清单外的层级值
        var db: OpaquePointer?
        guard sqlite3_open(fileURL.path, &db) == SQLITE_OK, let raw = db else {
            Issue.record("打不开测试库")
            return
        }
        defer { sqlite3_close(raw) }
        guard sqlite3_exec(raw, "UPDATE contacts SET level = 'bogus'", nil, nil, nil) == SQLITE_OK else {
            Issue.record("直改库失败")
            return
        }

        #expect {
            _ = try repository.contact(id: contact.id)
        } throws: { error in
            if case Repository.RepositoryError.unknownEnumValue = error { return true }
            return false
        }
    }
}
