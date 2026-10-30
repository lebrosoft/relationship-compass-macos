import Foundation
import Testing
import PeoplebookKit

/// 接缝 4：提醒阈值与自然日日期计算（spec「Testing Decisions」#4）。
struct ReminderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    // MARK: isOverdue

    @Test("重点：31 天逾期，30 天不逾期")
    func keyBoundary() {
        let contact = Contact(name: "X", level: .key)
        #expect(Reminder.isOverdue(contact: contact, lastInteraction: date(2026, 9, 1), now: date(2026, 10, 2), calendar: calendar))
        #expect(!Reminder.isOverdue(contact: contact, lastInteraction: date(2026, 9, 1), now: date(2026, 10, 1), calendar: calendar))
    }

    @Test("普通：91 天逾期，90 天不逾期")
    func normalBoundary() {
        let contact = Contact(name: "X", level: .normal)
        #expect(Reminder.isOverdue(contact: contact, lastInteraction: date(2026, 7, 1), now: date(2026, 10, 1), calendar: calendar))
        #expect(!Reminder.isOverdue(contact: contact, lastInteraction: date(2026, 7, 3), now: date(2026, 10, 1), calendar: calendar))
    }

    @Test("冷淡：从不逾期")
    func coldNeverOverdue() {
        let contact = Contact(name: "X", level: .cold)
        #expect(!Reminder.isOverdue(contact: contact, lastInteraction: date(2020, 1, 1), now: date(2026, 10, 30), calendar: calendar))
    }

    @Test("从未互动：永不逾期（即使重点）")
    func neverInteractedNeverOverdue() {
        let key = Contact(name: "X", level: .key)
        #expect(!Reminder.isOverdue(contact: key, lastInteraction: nil, now: date(2026, 10, 30), calendar: calendar))
    }

    // MARK: daysSince

    @Test("自然日差：跨零点立即记 1 天")
    func dayBoundary() {
        let from = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 23, minute: 50))!
        let to = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 0, minute: 10))!
        let days = Reminder.daysSince(from, to: to, calendar: calendar)
        #expect(days == 1)
    }

    @Test("同一天为 0")
    func sameDay() {
        let now = date(2026, 10, 30)
        let from = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 0, minute: 5))!
        #expect(Reminder.daysSince(from, to: now, calendar: calendar) == 0)
    }

    // MARK: lastInteractionDate

    @Test("最近互动取最大日期")
    func lastInteractionIsMax() {
        let old = Interaction(contactID: UUID(), kind: .wechat, date: date(2026, 1, 1))
        let new = Interaction(contactID: old.contactID, kind: .coffeeFaceToFace, date: date(2026, 10, 1))
        #expect(Reminder.lastInteractionDate([old, new]) == new.date)
    }

}
