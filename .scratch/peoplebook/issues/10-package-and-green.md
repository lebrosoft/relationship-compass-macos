# 10: 收尾打包与全量绿

## Parent

- #1（Spec: 人脉簿 v1）

## What to build

v1 交付闭环：提供构建 `.app` 的脚本（Release 构建 + 拼装bundle），让用户可以双击启动；README 覆盖构建 / 测试 / 打包与领域文档指引（词汇表、两份 ADR）；全量构建与测试绿，提交并推送到 GitHub。

## Acceptance criteria

- [ ] 脚本产出的 App 可双击启动并正常显示 6 假联系人的三栏界面
- [ ] README 含：`swift build` / `swift test` / 打包三步说明与文档索引
- [ ] `swift build` 与 `swift test` 全绿（测试含规格点名的搜索、导入、保存、日期计算四接缝）
- [ ] 全部改动提交并推送仓库

## Blocked by

- #8（07 互动时间线）
- #9（08 关系连线）
- #10（09 导入预览 sheet）