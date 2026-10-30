import Foundation

// MARK: - 联系人层级

/// 三档层级（见 GLOSSARY.md「层级」）。决定提醒阈值。
public enum Level: String, CaseIterable, Sendable, Codable, Hashable {
    case key
    case normal
    case cold

    public var label: String {
        switch self {
        case .key: "重点"
        case .normal: "普通"
        case .cold: "冷淡"
        }
    }

    /// 提醒阈值（天）。nil 表示从不提醒。
    public var reminderDays: Int? {
        switch self {
        case .key: 30
        case .normal: 90
        case .cold: nil
        }
    }
}

// MARK: - 互动类型

/// 固定清单（见 GLOSSARY.md「互动类型」）。raw value 仅作持久化键。
public enum InteractionKind: String, CaseIterable, Sendable, Codable, Hashable {
    case coffeeFaceToFace
    case phone
    case wechat
    case email
    case meeting
    case other

    public var label: String {
        switch self {
        case .coffeeFaceToFace: "喝咖啡/面谈"
        case .phone: "电话"
        case .wechat: "微信"
        case .email: "邮件"
        case .meeting: "会议"
        case .other: "其他"
        }
    }
}

// MARK: - 关系类型

/// 固定清单（见 GLOSSARY.md「关系类型」）。
public enum RelationshipKind: String, CaseIterable, Sendable, Codable, Hashable {
    case colleague
    case formerColleague
    case classmate
    case friend
    case family
    case partner
    case introducedVia

    public var label: String {
        switch self {
        case .colleague: "同事"
        case .formerColleague: "前同事"
        case .classmate: "同学"
        case .friend: "朋友"
        case .family: "家人"
        case .partner: "伴侣"
        case .introducedVia: "经介绍认识"
        }
    }
}

// MARK: - 联系人

public struct Contact: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var name: String
    public var phone: String
    public var email: String
    public var company: String
    public var title: String
    public var note: String
    public var level: Level
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        phone: String = "",
        email: String = "",
        company: String = "",
        title: String = "",
        note: String = "",
        level: Level = .normal,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.email = email
        self.company = company
        self.title = title
        self.note = note
        self.level = level
        self.createdAt = createdAt
    }
}

// MARK: - 互动

public struct Interaction: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    public var contactID: UUID
    public var kind: InteractionKind
    public var date: Date
    public var note: String

    public init(
        id: UUID = UUID(),
        contactID: UUID,
        kind: InteractionKind,
        date: Date,
        note: String = ""
    ) {
        self.id = id
        self.contactID = contactID
        self.kind = kind
        self.date = date
        self.note = note
    }
}

// MARK: - 联系人间关系

public struct Relationship: Identifiable, Hashable, Sendable, Codable {
    public var id: UUID
    /// 无方向语义的两个端点；仅为存储锚点。
    public var firstContactID: UUID
    public var secondContactID: UUID
    public var kind: RelationshipKind

    public init(
        id: UUID = UUID(),
        firstContactID: UUID,
        secondContactID: UUID,
        kind: RelationshipKind
    ) {
        self.id = id
        self.firstContactID = firstContactID
        self.secondContactID = secondContactID
        self.kind = kind
    }
}

// MARK: - 提醒 / 日期计算

/// 逾期逻辑（见 ADR 0002）：有互动记录、且最近一次互动距今超过层级阈值。
public enum Reminder {
    /// 最近一次互动的日期；从未互动返回 nil。
    public static func lastInteractionDate(_ interactions: [Interaction]) -> Date? {
        interactions.map(\.date).max()
    }

    /// 距今天数，按自然日（起点零点）计。
    public static func daysSince(
        _ date: Date, to now: Date, calendar: Calendar = .current
    ) -> Int? {
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: end).day
        return days
    }

    public static func isOverdue(
        contact: Contact,
        lastInteraction: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard let threshold = contact.level.reminderDays, let last = lastInteraction else {
            return false
        }
        return (daysSince(last, to: now, calendar: calendar) ?? 0) > threshold
    }
}
