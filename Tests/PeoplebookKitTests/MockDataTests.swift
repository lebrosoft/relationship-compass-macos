import Foundation
import Testing
@testable import PeoplebookKit

/// 假数据剧本（票 06）：断言挂在日期计算接缝上（规格「Testing Decisions」），
/// 相对 now 生成便于固定时钟验证。
struct MockDataTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test("6 个假联系人按剧本只有 2 个逾期")
    func twoOverdueInScenario() {
        let now = date(2026, 10, 30)
        let seed = MockData.seed(now: now, calendar: calendar)
        #expect(seed.contacts.count == 6)

        let byName = Dictionary(uniqueKeysWithValues: seed.contacts.map { ($0.name, $0) })

        func overdue(_ name: String) -> Bool {
            let contact = byName[name]!
            let last = Reminder.lastInteractionDate(
                seed.interactions.filter { $0.contactID == contact.id }
            )
            return Reminder.isOverdue(
                contact: contact, lastInteraction: last, now: now, calendar: calendar
            )
        }

        #expect(overdue("陈志远") == false)  // 重点，7 天前
        #expect(overdue("王芳") == true)     // 重点，40 天前
        #expect(overdue("李金陵") == false)  // 重点，零互动
        #expect(overdue("刘一舟") == true)   // 普通，120 天前
        #expect(overdue("赵晓萌") == false)  // 重点，2 天前
        #expect(overdue("孙明轩") == false)  // 冷淡，零互动
    }
}
