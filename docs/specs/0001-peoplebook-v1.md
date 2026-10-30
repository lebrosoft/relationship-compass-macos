# Spec: 人脉簿 (Peoplebook) v1 — 单机 macOS 人脉 CRM

> Terms follow [GLOSSARY.md](../../GLOSSARY.md); storage and reminder decisions follow
> [ADR 0001](../../docs/adr/0001-local-sqlite-single-user.md) and
> [ADR 0002](../../docs/adr/0002-level-driven-reminder-thresholds.md).

## Problem Statement

作为一个把人脉当资产维护的个人，我的联系人散在 Apple 通讯录和微信里，"关系"却无处安放：
谁上个月刚喝过咖啡、谁已经 4 个月没理、谁又是谁的引荐人，都只能靠记忆。通讯录只存属性不存
关系；OpenAI 式的团队 CRM 又太重、要账号要联网，隐私上也不放心放真人社交数据。

## Solution

**人脉簿（Peoplebook）**：macOS 上的单机 CRM。SwiftUI 两栏界面，左栏搜索+列表（逾期者挂红点）、
右栏单详情栏（资料卡 + 互动时间线 + 联系人间关系）。我与每个联系人的接触记录成一条条**互动**（带日期、类型、笔记），联系人之间
记录**联系人间关系**（同事、经介绍认识等）。每个联系人挂一个三档**层级**（重点/普通/冷淡），
层级自动决定"该维护了"的提醒阈值。支持 UTF-8 CSV 导入，导入前有**导入预览**，标注
**跳过**与**疑似重复**。数据纯本地 SQLite（ADR 0001），无账号无云。首版内置 6 个固定假
联系人撑起全部场景。

## User Stories

1. As a 个人用户, I want to 打开 app 就看到 6 个内置假联系人（无需导入即可上手），so that 我可以立刻体验梳理人脉的完整流程.
2. As a 个人用户, I want to 在两栏界面的左栏浏览联系人列表（姓名 + 公司），so that 我可以快速扫一遍我的人脉.
3. As a 个人用户, I want to 让列表中**逾期**的联系人显示一个红点，so that 我扫一眼就知道谁该主动联系了.
4. As a 个人用户, I want to 点击列表把某位联系人的详情固定在右栏详情栏，so that 我可以专注看一个人.
5. As a 个人用户, I want to 在详情页看到联系人的姓名、电话、邮箱、公司、职位，so that 我能核对并取用基本信息.
6. As a 个人用户, I want to 在详情页修改联系人的**层级**（重点/普通/冷淡），so that 提醒阈值跟着我对这段关系的重视程度走.
7. As a 个人用户, I want to 给联系人写一段自由文本**备注**，so that 我可以记下"他是怎么认识的、要注意什么"这类背景.
8. As a 个人用户, I want to 在详情页看到该联系人按时间倒序的**互动**时间线（日期 + 类型 + 笔记），so that 我能回顾"上次聊了什么".
9. As a 个人用户, I want to 新增一条互动（从固定六类选类型：喝咖啡/面谈、电话、微信、邮件、会议、其他；填日期与笔记），so that 时间线始终保持最新.
10. As a 个人用户, I want to 删除记错的互动，so that 时间线不被脏数据污染.
11. As a 个人用户, I want to 互动笔记作为**搜索**的次级结果聚合到对应联系人下，so that 我搜"融资"能找到那次聊融资的朋友.
12. As a 个人用户, I want to 搜索命中姓名、公司、职位、备注，so that 我能按任何属性找到人.
13. As a 个人用户, I want to 在两个联系人之间建立一条**联系人间关系**（从固定七类选类型），so that "张三把我介绍给李四"这种人脉结构被记录下来.
14. As a 个人用户, I want to 看到某联系人名下所有**联系人间关系**（另一端的姓名 + 类型），so that 我能看到局部的网络.
15. As a 个人用户, I want to 删除建错的关系边，so that 模型保持准确.
16. As a 个人用户, I want to 详情栏直接显示**逾期**横幅（例如"距上次互动已 40 天，重点阈值 30 天"），so that 不用我自己算.
17. As a 个人用户, I want to 系统按层级定阈值：重点 >30 天、普通 >90 天、冷淡不提醒（ADR 0002），so that 我只需维护一个三档判断，不用逐人配置.
18. As a 个人用户, I want to 从未有互动记录的联系人不算逾期，so that 刚导入的名单不会瞬间满屏红点.
19. As a 个人用户, I want to 点击导入按钮选择 UTF-8 CSV 文件，so that 我可以把表格里的联系人搬进来.
20. As a 个人用户, I want to 导入前看到**导入预览**（逐行：姓名、电话、公司，以及跳过/疑似重复标记），so that 我在数据进库前有最后一道闸门.
21. As a 个人用户, I want to 姓名与电话都命中的行默认**跳过**（可改判），so that 重复导入不会制造脏数据.
22. As a 个人用户, I want to 仅姓名命中的行标记**疑似重复**但默认仍导入（可改判），so that 合法的重名不被误杀.
23. As a 个人用户, I want to 在预览里逐行取消或恢复导入，so that 最终权限在我手里.
24. As a 个人用户, I want to CSV 首行是表头、列名为 姓名/电话/邮箱/公司/职位 且允许缺列（电话后列可空），so that 我的表格不用为导入改造.
25. As a 个人用户, I want to 导入的联系人默认**层级**为普通，so that 系统不会替我把陌生人定性为重要.
26. As a 个人用户, I want to 删除联系人时其互动与关系边一并删除，so that 不会留下悬挂引用.
27. As a 个人用户, I want to 所有数据存在本机 Application Support 下的 SQLite 文件且无任何账号/云同步（ADR 0001），so that 我的社交数据不出我的电脑.
28. As a 个人用户, I want to 一个内置示例 CSV 可一键填入预览（含 1 个跳过、1 个疑似重复、2 个新增），so that 我不开 Excel 也能体验导入门到门.

## Implementation Decisions

- **两个 target + 一个测试 target**：`PeoplebookKit`（纯领域库，无 UI 依赖）、`PeoplebookApp`
  （SwiftUI 可执行 target，依赖 Kit）、`PeoplebookKitTests`（Swift Testing / XCTest，只打 Kit）。
- **领域模型**（Kit）：`Contact`（含 `note` 备注）、`Interaction`（归属唯一 `Contact`，带
  `InteractionKind`/`Date`/笔记）、`Relationship`（两个 `Contact` 的无向边，带
  `RelationshipKind`）。
- **三档层级** `Level(key/normal/cold)`：显示名 重点/普通/冷淡；`reminderDays` 为 30/90/nil。
  阈值语义见 ADR 0002；**从未互动的联系人永不算逾期**。
- **提醒/日期计算**归 `Reminder`：`lastInteractionDate`（max 互动日期）、`daysSince`（按
  自然日起点计算）、`isOverdue`（阈值 + 最近互动天数）。
- **搜索**归 `ContactSearch.search`：主命中（姓名、公司、职位、备注）+ 次级命中（互动笔记，
  聚合到联系人）；大小写/变音不敏感；空查询返回全部。
- **导入**归 `CSVImporter`：RFC4180 风格解析（引号内逗号/换行/转义引号、BOM 剥离）；表头
  必须含"姓名"，数据行姓名为空则忽略；电话归一化（去非数字、剥 +86 前缀）；去重按
  姓名+电话 → skip，仅姓名 → 疑似重复。
- **存储**归 `Repository`（ADR 0001）：系统 SQLite（`SQLite3` 模块，零第三方依赖），三张表
  `contacts / interactions / relationships`，外键级联删除（联系人删除连带互动与关系边），全部
  upsert 按 UUID 主键。
- **UI**（App target）：`NavigationSplitView` 两栏（搜索+列表 / 详情），详情含层级
  Picker、备注编辑、互动时间线（增删）与关系区（增删）；逾期横幅与列表红点直接读
  `Reminder` 的域函数，不在 UI 复制阈值逻辑。
- **假数据**归 `MockData.seed(now:)`：6 人固定剧本——陈志远(重点/7 天前，新鲜)、王芳(重点/40
  天前，逾期)、李金陵(重点/零互动，永不逾期)、刘一舟(普通/120 天前，逾期)、赵晓萌(重点/2 天
  前，新鲜)、孙明轩(冷淡/零互动)；关系边：陈–王(同事)、王–赵(经介绍认识)、陈–刘(前同事)。
  空库自动播种；日期相对 `now`，逾期与否随时钟自动成立。

## Testing Decisions

- **接缝（已与需求方确认）**：全部自动化测试压在 `PeoplebookKit` 的四个纯域接缝上，UI 层
  （`PeoplebookApp`）不写自动化测试；`AppModel` 是薄胶水，走过场者不测。
  1. **搜索** → `ContactSearch.search`（主/次命中、空查询、聚合）
  2. **导入** → `CSVImporter`（编码/解析/表头规则/预览标记/电话归一化）
  3. **保存** → `Repository`（临时文件 SQLite 落盘往返、upsert、级联删除）
  4. **日期计算** → `Reminder`（固定时钟判逾期、自然日天数、零互动永不算逾期）
- **好测试的标准**：只测接缝的外部行为（输入→输出），不测 SQL 文本、Swift 存储细节或
  `UserDefaults` 之类实现中介；每个测试自带近似隔离环境（`:memory:` 或
  `TemporaryDirectory` 下的随机文件），互不依赖顺序。
- **先例**：本仓库无既有测试，首套测试即成为先例；以 `MockData.seed(now:)` 的固定相对日期
  与测试内固定 `now` 作为"时间无关"的范式。

## Out of Scope

- 云同步、多用户、账号体系（ADR 0001 明确不做）
- 自定义互动类型 / 关系类型（各自固定清单）
- 标签 / 分组（被三档**层级**取代）
- vCard 导入、Excel xlsx 导入（仅 UTF-8 CSV）
- 自动热度衰减、逐联系人自定义阈值（ADR 0002 的否决方案）
- 人脉网络图可视化（探索分析方向整体押后）

## Further Notes

- 本 spec 由 2 轮 grilling（设计树 16 个决策全部确认）蒸馏而来；领域词汇的唯一权威是
  `GLOSSARY.md`，实现中命名凡与其冲突应回改词汇表而不是造私语。
- 首版交付判定：`swift build` 通过、`swift test` 四接缝全绿、`swift run` 出现 6 假联系人的
  两栏界面且剧本场景（红点/逾期横幅/关系边/导入预览标记）可现场演示。
- 提供构建 `.app` 的脚本 `scripts/make-app.sh`，便于双击启动与自分发。
