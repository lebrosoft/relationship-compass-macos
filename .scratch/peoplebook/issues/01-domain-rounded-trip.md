# 01: 领域落盘链路（模型 + SQLite Repository）

## Parent

- #1（Spec: 人脉簿 v1）

## What to build

"人脉簿"的数据底座：联系人 / 互动 / 联系人间关系 三类记录可以保存到本机 SQLite 并原样读回。遵循 ADR 0001（纯本地、单用户、无云）。工作区已有草稿实现，本票以测试全绿与评审为验收。

## Acceptance criteria

- [ ] 联系人（含层级、备注）、互动、关系边经 upsert 保存后可原样读回（各字段含 UUID 主键）
- [ ] 更新已存在记录不产生重复行
- [ ] 删除联系人时级联删除其互动与关系边；外键约束开启
- [ ] 保存 / 往返 / 级联删除测试（临时目录文件库）通过；`swift test` 该范围全绿

## Blocked by

None (can start immediately)
