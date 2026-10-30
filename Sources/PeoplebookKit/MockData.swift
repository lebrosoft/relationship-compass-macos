import Foundation

/// 首版内置的 6 个固定假联系人（含所有"戏"：新鲜互动、重点逾期 40 天、
/// 普通逾期 120 天、重点但从未互动、冰冷淡、以及一个「经介绍认识」链条）。
public enum MockData {    public struct Seed: Sendable {
        public var contacts: [Contact]
        public var interactions: [Interaction]
        public var relationships: [Relationship]
    }

    /// - Parameter now: 以哪个时间点为"今天"生成相对日期（测试可固定）。
    public static func seed(now: Date = Date(), calendar: Calendar = .current) -> Seed {
        func daysAgo(_ n: Int) -> Date {
            calendar.date(byAdding: .day, value: -n, to: now)!
        }

        let chen = Contact(
            name: "陈志远",
            phone: "13800000001",
            email: "chen.zhiyuan@example.com",
            company: "云帆科技",
            title: "技术合伙人",
            note: "老搭档，做 AI 基础设施，关键时候能拉我一把。",
            level: .key,
            createdAt: daysAgo(400)
        )
        let wang = Contact(
            name: "王芳",
            phone: "13900000002",
            email: "wang.fang@example.com",
            company: "青竹资本",
            title: "投资总监",
            note: "帮我介绍过好几位创始人，记得找机会感谢。",
            level: .key,
            createdAt: daysAgo(300)
        )
        let li = Contact(
            name: "李金陵",
            phone: "13700000003",
            email: "li.jinling@example.com",
            company: "金陵工作室",
            title: "独立设计师",
            note: "上个月饭局刚认识，还没深聊。",
            level: .key,
            createdAt: daysAgo(35)
        )
        let liu = Contact(
            name: "刘一舟",
            phone: "13600000004",
            email: "liu.yizhou@example.com",
            company: "流云出行",
            title: "运营负责人",
            note: "前前公司同事，人脉很广。",
            level: .normal,
            createdAt: daysAgo(200)
        )
        let zhao = Contact(
            name: "赵晓萌",
            phone: "13500000005",
            email: "zhao.xiaomeng@example.com",
            company: "未眠实验室",
            title: "产品经理",
            note: "聊产品很有火花，值得约第二次。",
            level: .key,
            createdAt: daysAgo(20)
        )
        let sun = Contact(
            name: "孙明轩",
            phone: "13400000006",
            email: "sun.mingxuan@example.com",
            company: "恒信律所",
            title: "律师",
            note: "处理过合同纠纷，暂时没往来需求。",
            level: .cold,
            createdAt: daysAgo(500)
        )

        let chenInteractions: [Interaction] = [
            Interaction(
                contactID: chen.id, kind: .coffeeFaceToFace, date: daysAgo(7),
                note: "聊了他新业务的卡点，提到缺一个靠谱的运营合伙人。"
            ),
            Interaction(
                contactID: chen.id, kind: .wechat, date: daysAgo(12),
                note: "转了他一篇行业分析的链接，约了下月饭局。"
            ),
        ]
        let wangInteraction = Interaction(
            contactID: wang.id, kind: .meeting, date: daysAgo(40),
            note: "开会聊项目融资进展，她说会帮忙留意投资圈的机会。"
        )
        let liuInteractions: [Interaction] = [
            Interaction(
                contactID: liu.id, kind: .phone, date: daysAgo(120),
                note: "电话聊行业近况，他说流云出行在扩业务线。"
            ),
            Interaction(
                contactID: liu.id, kind: .email, date: daysAgo(150),
                note: "邮件往来，讨论老同事聚会的事。"
            ),
        ]
        let zhaoInteractions: [Interaction] = [
            Interaction(
                contactID: zhao.id, kind: .coffeeFaceToFace, date: daysAgo(2),
                note: "在南山书屋第一次见面，聊了两小时产品。"
            ),
            Interaction(
                contactID: zhao.id, kind: .wechat, date: daysAgo(5),
                note: "加了微信，互相发了几篇产品设计的文章。"
            ),
        ]

        let chenWang = Relationship(
            firstContactID: chen.id, secondContactID: wang.id, kind: .colleague
        )
        let wangZhao = Relationship(
            firstContactID: wang.id, secondContactID: zhao.id, kind: .introducedVia
        )
        let chenLiu = Relationship(
            firstContactID: chen.id, secondContactID: liu.id, kind: .formerColleague
        )

        let interactions =
            chenInteractions + [wangInteraction] + liuInteractions + zhaoInteractions
        return Seed(
            contacts: [chen, wang, li, liu, zhao, sun],
            interactions: interactions,
            relationships: [chenWang, wangZhao, chenLiu]
        )
    }
}
