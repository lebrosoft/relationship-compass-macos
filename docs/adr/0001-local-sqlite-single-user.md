# 纯本地 SQLite，单用户，无账号无云同步

人脉簿的个人人脉数据属隐私范畴，v1 放弃账号/云同步/Web 服务，全部数据存储在用户机器上的单个 SQLite 文件（Application Support 目录）。个人使用场景下消除后端成本与隐私面；云同步只需以后在 Repository 之上加同步层，不改领域模型。备选（Core Data、JSON 文件）被否决：Core Data 引入重量级依赖，JSON 在关系/互动的数据一致性与数量增长下不可靠。
