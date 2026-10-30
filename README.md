# 人脉簿 (Peoplebook)

macOS 上的单机人脉 CRM：记录与回顾"我和谁、聊过什么、多久没联系"，用层级驱动的提醒推动关系维护。纯本地 SQLite 存储（ADR 0001），无账号、无云。

- 规格 / 票板：[docs/specs/0001-peoplebook-v1.md](docs/specs/0001-peoplebook-v1.md) · GitHub Issues（ready-for-agent 票逐张实现）
- 领域词汇：[GLOSSARY.md](GLOSSARY.md) —— 实现命名与其冲突时应回改词汇表，而不是造私语

## 构建 / 测试 / 打包

```bash
swift build                 # 构建（Debug）
swift test                  # 全量测试（＃域层四接缝：搜索/导入/保存/日期计算）
./scripts/make-app.sh       # Release 构建 + 产出 dist/人脉簿.app（可双击启动）
```

数据存储在 `~/Library/Application Support/Peoplebook/peoplebook.sqlite3`；首次启动自动播种 6 个假联系人（含 2 个逾期、1 个「经介绍认识」链条），活动资料可随时删库重来。

## 架构

- `PeoplebookKit` —— 纯领域库：模型与层级、`Reminder`（日期计算/逾期）、`ContactSearch`（主命中 + 互动笔记次级聚合）、`CSVImporter`（UTF-8/RFC4180/去重标记）、`Repository`（SQLite，级联删除）、`MockData`（六人剧本）
- `PeoplebookApp` —— SwiftUI 三栏（搜索列表 / 互动时间线 / 资料与关系）+ 导入预览 sheet

UI 层按规格不写自动化测试；自动化全部压在 PeoplebookKit 四个接缝上。

## 关键决策（ADR）

- [0001 纯本地 SQLite，单用户，无账号无云](docs/adr/0001-local-sqlite-single-user.md)
- [0002 层级驱动的提醒阈值（重点 30 天 / 普通 90 天 / 冷淡不提醒）](docs/adr/0002-level-driven-reminder-thresholds.md)
