import Foundation
import SQLite3

/// 纯本地 SQLite 存储（见 ADR 0001）。单用户、无云。
/// 线程约定：所有方法非隔离、同步；调用方（UI 在 MainActor，测试在测试线程）自行串行化。
public final class Repository: @unchecked Sendable {
    private var db: OpaquePointer?
    private let path: String

    /// - Parameter path: SQLite 文件路径，或 `:memory:`。
    public init(path: String) throws {
        self.path = path
        var handle: OpaquePointer?
        guard sqlite3_open(path, &handle) == SQLITE_OK, let opened = handle else {
            if let handle { sqlite3_close(handle) }
            throw RepositoryError.cannotOpen(path)
        }
        db = opened
        try exec("PRAGMA foreign_keys = ON")
        try migrate()
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    public enum RepositoryError: Error, Equatable, Sendable {
        case cannotOpen(String)
        case sqlite(String)
        case notFound
        /// 库中出现了固定清单之外的枚举值（层级/类型），拒绝静默改类。
        case unknownEnumValue(column: String, raw: String)
    }

    // MARK: - 联系人

    /// 按主键 upsert。
    public func saveContact(_ contact: Contact) throws {
        try upsert(
            table: "contacts",
            id: contact.id,
            updateSQL: """
                UPDATE contacts SET name = ?, phone = ?, email = ?, company = ?,
                title = ?, note = ?, level = ? WHERE id = ?
                """,
            insertSQL: """
                INSERT INTO contacts (id, name, phone, email, company, title, note, level, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
            bindsUpdate: { stmt in
                bind(stmt, 1, contact.name)
                bind(stmt, 2, contact.phone)
                bind(stmt, 3, contact.email)
                bind(stmt, 4, contact.company)
                bind(stmt, 5, contact.title)
                bind(stmt, 6, contact.note)
                bind(stmt, 7, contact.level.rawValue)
                bind(stmt, 8, contact.id.uuidString)
            },
            bindsInsert: { stmt in
                bind(stmt, 1, contact.id.uuidString)
                bind(stmt, 2, contact.name)
                bind(stmt, 3, contact.phone)
                bind(stmt, 4, contact.email)
                bind(stmt, 5, contact.company)
                bind(stmt, 6, contact.title)
                bind(stmt, 7, contact.note)
                bind(stmt, 8, contact.level.rawValue)
                bind(stmt, 9, contact.createdAt.timeIntervalSinceReferenceDate)
            }
        )
    }

    public func contact(id: UUID) throws -> Contact {
        var result: Contact?
        try query(
            """
            SELECT id, name, phone, email, company, title, note, level, created_at
            FROM contacts WHERE id = ?
            """,
            [id.uuidString]
        ) { row in
            result = try Self.contact(from: row)
        }
        guard let result else { throw RepositoryError.notFound }
        return result
    }

    public func allContacts() throws -> [Contact] {
        var result: [Contact] = []
        try query(
            """
            SELECT id, name, phone, email, company, title, note, level, created_at
            FROM contacts ORDER BY created_at ASC
            """
        ) { row in
            result.append(try Self.contact(from: row))
        }
        return result
    }

    /// 级联删除该联系人的互动与关系（外键 ON DELETE CASCADE）。
    public func deleteContact(id: UUID) throws {
        try exec("DELETE FROM contacts WHERE id = ?") { bind($0, 1, id.uuidString) }
    }

    // MARK: - 互动

    public func saveInteraction(_ interaction: Interaction) throws {
        try upsert(
            table: "interactions",
            id: interaction.id,
            updateSQL: "UPDATE interactions SET contact_id = ?, kind = ?, date = ?, note = ? WHERE id = ?",
            insertSQL: """
                INSERT INTO interactions (id, contact_id, kind, date, note)
                VALUES (?, ?, ?, ?, ?)
                """,
            bindsUpdate: { stmt in
                bind(stmt, 1, interaction.contactID.uuidString)
                bind(stmt, 2, interaction.kind.rawValue)
                bind(stmt, 3, interaction.date.timeIntervalSinceReferenceDate)
                bind(stmt, 4, interaction.note)
                bind(stmt, 5, interaction.id.uuidString)
            },
            bindsInsert: { stmt in
                bind(stmt, 1, interaction.id.uuidString)
                bind(stmt, 2, interaction.contactID.uuidString)
                bind(stmt, 3, interaction.kind.rawValue)
                bind(stmt, 4, interaction.date.timeIntervalSinceReferenceDate)
                bind(stmt, 5, interaction.note)
            }
        )
    }

    public func interactions(forContact contactID: UUID) throws -> [Interaction] {
        var result: [Interaction] = []
        try query(
            """
            SELECT id, contact_id, kind, date, note FROM interactions
            WHERE contact_id = ? ORDER BY date DESC
            """,
            [contactID.uuidString]
        ) { row in
            result.append(try Self.interaction(from: row))
        }
        return result
    }

    public func allInteractions() throws -> [Interaction] {
        var result: [Interaction] = []
        try query(
            "SELECT id, contact_id, kind, date, note FROM interactions ORDER BY date DESC"
        ) { row in
            result.append(try Self.interaction(from: row))
        }
        return result
    }

    public func deleteInteraction(id: UUID) throws {
        try exec("DELETE FROM interactions WHERE id = ?") { bind($0, 1, id.uuidString) }
    }

    // MARK: - 联系人间关系

    public func saveRelationship(_ relationship: Relationship) throws {
        try upsert(
            table: "relationships",
            id: relationship.id,
            updateSQL: "UPDATE relationships SET a_id = ?, b_id = ?, kind = ? WHERE id = ?",
            insertSQL: "INSERT INTO relationships (id, a_id, b_id, kind) VALUES (?, ?, ?, ?)",
            bindsUpdate: { stmt in
                bind(stmt, 1, relationship.firstContactID.uuidString)
                bind(stmt, 2, relationship.secondContactID.uuidString)
                bind(stmt, 3, relationship.kind.rawValue)
                bind(stmt, 4, relationship.id.uuidString)
            },
            bindsInsert: { stmt in
                bind(stmt, 1, relationship.id.uuidString)
                bind(stmt, 2, relationship.firstContactID.uuidString)
                bind(stmt, 3, relationship.secondContactID.uuidString)
                bind(stmt, 4, relationship.kind.rawValue)
            }
        )
    }

    public func relationships() throws -> [Relationship] {
        var result: [Relationship] = []
        try query("SELECT id, a_id, b_id, kind FROM relationships ORDER BY rowid") { row in
            result.append(try Self.relationship(from: row))
        }
        return result
    }

    /// 涉及某联系人的全部关系边（两端任一命中）。
    public func relationships(forContact contactID: UUID) throws -> [Relationship] {
        var result: [Relationship] = []
        try query(
            """
            SELECT id, a_id, b_id, kind FROM relationships
            WHERE a_id = ? OR b_id = ? ORDER BY rowid
            """,
            [contactID.uuidString, contactID.uuidString]
        ) { row in
            result.append(try Self.relationship(from: row))
        }
        return result
    }

    public func deleteRelationship(id: UUID) throws {
        try exec("DELETE FROM relationships WHERE id = ?") { bind($0, 1, id.uuidString) }
    }

    // MARK: - 行解码

    private static func contact(from row: Row) throws -> Contact {
        guard
            let id = row.uuid(0),
            let name = row.string(1),
            let created = row.double(8)
        else { throw RepositoryError.notFound }
        return Contact(
            id: id,
            name: name,
            phone: row.string(2) ?? "",
            email: row.string(3) ?? "",
            company: row.string(4) ?? "",
            title: row.string(5) ?? "",
            note: row.string(6) ?? "",
            level: try row.enumValue(7, column: "level", type: Level.self),
            createdAt: Date(timeIntervalSinceReferenceDate: created)
        )
    }

    private static func interaction(from row: Row) throws -> Interaction {
        guard
            let id = row.uuid(0),
            let contactID = row.uuid(1),
            let date = row.double(3)
        else { throw RepositoryError.notFound }
        return Interaction(
            id: id,
            contactID: contactID,
            kind: try row.enumValue(2, column: "kind", type: InteractionKind.self),
            date: Date(timeIntervalSinceReferenceDate: date),
            note: row.string(4) ?? ""
        )
    }

    private static func relationship(from row: Row) throws -> Relationship {
        guard
            let id = row.uuid(0),
            let aID = row.uuid(1),
            let bID = row.uuid(2)
        else { throw RepositoryError.notFound }
        return Relationship(
            id: id,
            firstContactID: aID,
            secondContactID: bID,
            kind: try row.enumValue(3, column: "kind", type: RelationshipKind.self)
        )
    }

    struct Row {
        let stmt: OpaquePointer
        func string(_ i: Int32) -> String? {
            guard let raw = sqlite3_column_text(stmt, i) else { return nil }
            return String(cString: raw)
        }
        func double(_ i: Int32) -> Double? {
            guard sqlite3_column_type(stmt, i) != SQLITE_NULL else { return nil }
            return sqlite3_column_double(stmt, i)
        }
        func enumValue<T: RawRepresentable>(_ i: Int32, column: String, type: T.Type = T.self) throws -> T where T.RawValue == String {
            guard let raw = string(i), let value = T(rawValue: raw) else {
                throw RepositoryError.unknownEnumValue(column: column, raw: string(i) ?? "(null)")
            }
            return value
        }
        func uuid(_ i: Int32) -> UUID? {
            string(i).flatMap(UUID.init(uuidString:))
        }
    }

    // MARK: - SQLite 底层

    private func migrate() throws {
        try exec(
            """
            CREATE TABLE IF NOT EXISTS contacts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                phone TEXT NOT NULL DEFAULT '',
                email TEXT NOT NULL DEFAULT '',
                company TEXT NOT NULL DEFAULT '',
                title TEXT NOT NULL DEFAULT '',
                note TEXT NOT NULL DEFAULT '',
                level TEXT NOT NULL DEFAULT 'normal',
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS interactions (
                id TEXT PRIMARY KEY,
                contact_id TEXT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
                kind TEXT NOT NULL,
                date REAL NOT NULL,
                note TEXT NOT NULL DEFAULT ''
            );
            CREATE TABLE IF NOT EXISTS relationships (
                id TEXT PRIMARY KEY,
                a_id TEXT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
                b_id TEXT NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
                kind TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS interactions_contact ON interactions(contact_id);
            """
        )
    }

    private func exec(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>? = nil
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message: String
            if let error {
                message = String(cString: error)
                sqlite3_free(error)
            } else {
                message = "exec failed"
            }
            throw RepositoryError.sqlite(message)
        }
    }

    private func exec(_ sql: String, _ bind: (OpaquePointer) -> Void) throws {
        try withStatement(sql) { stmt in
            bind(stmt)
            try stepUntilDone(stmt)
        }
    }

    private func query(
        _ sql: String, _ params: [String] = [], consume: (Row) throws -> Void
    ) throws {
        try withStatement(sql) { stmt in
            for (index, param) in params.enumerated() {
                bind(stmt, Int32(index + 1), param)
            }
            while true {
                let rc = sqlite3_step(stmt)
                if rc == SQLITE_ROW { try consume(Row(stmt: stmt)) }
                else if rc == SQLITE_DONE { break }
                else { throw RepositoryError.sqlite(lastError()) }
            }
        }
    }

    /// 共用 upsert：主键存在 → 更新，否则插入。
    private func upsert(
        table: String,
        id: UUID,
        updateSQL: String,
        insertSQL: String,
        bindsUpdate: (OpaquePointer) -> Void,
        bindsInsert: (OpaquePointer) -> Void
    ) throws {
        let exists = try scalarBool("SELECT 1 FROM \(table) WHERE id = ?", [id.uuidString])
        try exec(exists ? updateSQL : insertSQL) { stmt in
            (exists ? bindsUpdate : bindsInsert)(stmt)
        }
    }

    private func scalarBool(_ sql: String, _ params: [String] = []) throws -> Bool {
        var found = false
        try query(sql, params) { _ in found = true }
        return found
    }

    private func withStatement(_ sql: String, _ body: (OpaquePointer) throws -> Void) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let prepared = stmt else {
            throw RepositoryError.sqlite(lastError())
        }
        defer { sqlite3_finalize(prepared) }
        try body(prepared)
    }

    private func stepUntilDone(_ stmt: OpaquePointer) throws {
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { return }
            if rc == SQLITE_ROW { continue }  // 不期望 SELECT，但容错
            throw RepositoryError.sqlite(lastError())
        }
    }

    private func bind(_ stmt: OpaquePointer, _ index: Int32, _ text: String) {
        sqlite3_bind_text(
            stmt, index, text, -1,
            unsafeBitCast(-1, to: sqlite3_destructor_type.self)  // SQLITE_TRANSIENT
        )
    }

    private func bind(_ stmt: OpaquePointer, _ index: Int32, _ value: Double) {
        sqlite3_bind_double(stmt, index, value)
    }

    private func lastError() -> String {
        String(cString: sqlite3_errmsg(db))
    }
}
