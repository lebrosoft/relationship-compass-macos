import Foundation
import Testing
import PeoplebookKit

/// 接缝 1：搜索（主命中 + 互动笔记次级聚合）（spec「Testing Decisions」#1）。
struct ContactSearchTests {
    private let chen = Contact(name: "陈志远", company: "云帆科技", title: "技术合伙人", note: "老搭档")
    private let wang = Contact(name: "王芳", company: "青竹资本", title: "投资总监", note: "")
    private let li = Contact(name: "李金陵", company: "金陵工作室", title: "设计师", note: "刚认识")

    private var contacts: [Contact] { [chen, wang, li] }

    private func interaction(contact: Contact, note: String) -> Interaction {
        Interaction(contactID: contact.id, kind: .meeting, date: Date(timeIntervalSince1970: 0), note: note)
    }

    @Test("空查询：返回全部且顺序不变")
    func emptyQueryReturnsAll() {
        let results = ContactSearch.search(
            contacts: contacts, interactions: [], query: "   "
        )
        #expect(results.map(\.contact.id) == contacts.map(\.id))
        #expect(results.allSatisfy { $0.secondaryNotes.isEmpty })
    }

    @Test("姓名命中")
    func nameMatch() {
        let results = ContactSearch.search(contacts: contacts, interactions: [], query: "陈志远")
        #expect(results.map(\.contact.name) == ["陈志远"])
    }

    @Test("公司命中")
    func companyMatch() {
        let results = ContactSearch.search(contacts: contacts, interactions: [], query: "青竹资本")
        #expect(results.map(\.contact.name) == ["王芳"])
    }

    @Test("备注命中")
    func noteMatch() {
        let results = ContactSearch.search(contacts: contacts, interactions: [], query: "刚认识")
        #expect(results.map(\.contact.name) == ["李金陵"])
    }

    @Test("仅互动笔记命中 → 次级结果，聚合到联系人")
    func secondaryInteractionNotes() {
        let note = interaction(contact: chen, note: "聊了他公司的融资进展")
        let results = ContactSearch.search(
            contacts: contacts, interactions: [note], query: "融资"
        )
        let chenResult = results.first { $0.contact.id == chen.id }
        #expect(chenResult?.secondaryNotes == [note])
    }

    @Test("次级命中排序：主命中在前")
    func primaryBeforeSecondary() {
        let note = interaction(contact: li, note: "聊了融资后的团队扩张")
        let results = ContactSearch.search(
            contacts: contacts, interactions: [note], query: "融资"
        )
        #expect(results.first?.contact.id == li.id)
    }

    @Test("互动笔记按日期倒序聚合")
    func secondaryNotesSortedByDateDesc() {
        let old = Interaction(
            contactID: chen.id, kind: .email, date: Date(timeIntervalSince1970: 100), note: "谈融资"
        )
        let recent = Interaction(
            contactID: chen.id, kind: .meeting, date: Date(timeIntervalSince1970: 200), note: "又谈融资"
        )
        let results = ContactSearch.search(contacts: contacts, interactions: [old, recent], query: "融资")
        let notes = results.first { $0.contact.id == chen.id }?.secondaryNotes
        #expect(notes == [recent, old])
    }

    @Test("英文及大小写不敏感：备注 API 也能被 api 命中")
    func caseInsensitive() {
        let api = Contact(name: "列夫", company: "", title: "", note: "对接 Stripe API")
        let results = ContactSearch.search(contacts: [api], interactions: [], query: "api")
        #expect(results.map(\.contact.name) == ["列夫"])
    }

    @Test("未命中为空")
    func noHit() {
        #expect(ContactSearch.search(contacts: contacts, interactions: [], query: "不存在的词").isEmpty)
    }
}
