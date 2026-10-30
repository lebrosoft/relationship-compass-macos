import Foundation

/// 搜索域规则（spec「Implementation Decisions」：搜索命中姓名、公司、职位、备注；
/// 互动笔记为次级结果，聚合到对应联系人下）。
public struct SearchResult: Identifiable, Hashable, Sendable {
    public let contact: Contact
    /// 该联系人的、笔记命中查询词的互动（次级命中）。
    public let secondaryNotes: [Interaction]
    public var id: UUID { contact.id }
}

public enum ContactSearch {
    /// query 为空 → 返回全部联系人（无次级命中），保持传入顺序。
    public static func search(
        contacts: [Contact],
        interactions: [Interaction],
        query: String
    ) -> [SearchResult] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return contacts.map { SearchResult(contact: $0, secondaryNotes: []) }
        }
        let byContact = Dictionary(grouping: interactions, by: \.contactID)
        var results: [SearchResult] = []
        var secondaryOnly: [SearchResult] = []
        for contact in contacts {
            let primary =
                [contact.name, contact.company, contact.title, contact.note]
                .contains { fuzzy($0, contains: query) }
            let notes =
                (byContact[contact.id] ?? [])
                .filter { fuzzy($0.note, contains: query) }
                .sorted { $0.date > $1.date }
            if primary {
                results.append(SearchResult(contact: contact, secondaryNotes: notes))
            } else if !notes.isEmpty {
                secondaryOnly.append(SearchResult(contact: contact, secondaryNotes: notes))
            }
        }
        return results + secondaryOnly
    }

    private static func fuzzy(_ text: String, contains query: String) -> Bool {
        text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
