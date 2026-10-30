import Foundation
import Testing
import PeoplebookKit

/// 接缝 2：CSV 解码 / 解析 / 导入预览与去重标记（spec「Testing Decisions」#2）。
struct CSVImporterTests {

    // MARK: 解码

    @Test("BOM 剥离")
    func stripsBOM() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append("姓名\n张三".data(using: .utf8)!)
        #expect(try CSVImporter.decode(data) == "姓名\n张三")
    }

    @Test("空数据不可解码")
    func emptyDataThrows() {
        #expect(throws: CSVImporter.ImportError.undecodable) {
            try CSVImporter.decode(Data())
        }
    }

    // MARK: 解析

    @Test("基础解析：表头与数据行")
    func parsesBasicRows() throws {
        let csv = """
        姓名,电话,邮箱
        张三,13800000000,zhang@example.com
        李四,13900000000,
        """
        let parsed = try CSVImporter.parse(csv)
        #expect(parsed.header == ["姓名", "电话", "邮箱"])
        #expect(parsed.rows.count == 2)
        #expect(parsed.rows[0][1] == "13800000000")
    }

    @Test("引号内的逗号、换行与转义引号")
    func parsesQuotedFields() throws {
        let csv = """
        姓名,公司,职位
        张三,"云帆科技,发展部","技术""架构""组"
        李四,"多行公司
        名",总监
        """
        let parsed = try CSVImporter.parse(csv)
        #expect(parsed.rows[0][1] == "云帆科技,发展部")
        #expect(parsed.rows[0][2] == "技术\"架构\"组")
        #expect(parsed.rows[1][1] == "多行公司\n名")
    }

    @Test("CRLF 行尾")
    func parsesCRLF() throws {
        let parsed = try CSVImporter.parse("姓名,电话\r\n张三,138\r\n李四,139\r\n")
        #expect(parsed.rows.count == 2)
        #expect(parsed.rows[1][0] == "李四")
    }

    @Test("缺「姓名」列报错")
    func missingNameColumnThrows() {
        #expect(throws: CSVImporter.ImportError.missingNameColumn) {
            try CSVImporter.parse("电话,邮箱\n138,a@x.com")
        }
    }

    @Test("无表头报错")
    func missingHeaderThrows() {
        #expect(throws: CSVImporter.ImportError.missingHeader) {
            try CSVImporter.parse("")
        }
    }

    @Test("只有表头没有数据行报错")
    func emptyFileThrows() {
        #expect(throws: CSVImporter.ImportError.emptyFile) {
            try CSVImporter.parse("姓名,电话\n")
        }
    }

    // MARK: 预览与去重标记

    private var existing: [Contact] {
        [
            Contact(name: "陈志远", phone: "13800000001"),
            Contact(name: "王芳", phone: "13900000002"),
        ]
    }

    @Test("姓名+电话同时命中 → 默认跳过")
    func phoneDuplicateSkipped() throws {
        let candidates = try CSVImporter.preview(
            csvText: """
            姓名,电话,邮箱,公司,职位
            陈志远,138 0000 0001,,云帆科技,CTO
            """,
            existing: existing
        )
        #expect(candidates.count == 1)
        #expect(candidates[0].skip)
        #expect(!candidates[0].suspectedDuplicate)
    }

    @Test("+86 前缀归一化后命中 → 跳过")
    func countryCodeNormalized() throws {
        let candidates = try CSVImporter.preview(
            csvText: """
            姓名,电话
            陈志远,+86 13900000002
            """,
            existing: existing
        )
        #expect(candidates.count == 1)
        #expect(candidates[0].skip)
    }

    @Test("仅姓名命中 → 疑似重复，默认仍导入")
    func nameDuplicateSuspected() throws {
        let candidates = try CSVImporter.preview(
            csvText: """
            姓名,电话
            王芳,13300000009
            """,
            existing: existing
        )
        #expect(candidates[0].suspectedDuplicate)
        #expect(!candidates[0].skip)
    }

    @Test("全新联系人 → 无任何标记")
    func freshRow() throws {
        let candidates = try CSVImporter.preview(
            csvText: """
            姓名,电话,邮箱,公司,职位
            周雨桐,13300000011,zhou@example.com,拾光影像,摄影师
            """,
            existing: existing
        )
        #expect(!candidates[0].skip)
        #expect(!candidates[0].suspectedDuplicate)
        #expect(candidates[0].makeContact().level == .normal)
    }

    @Test("姓名为空的行被忽略")
    func blankNameRowIgnored() throws {
        let candidates = try CSVImporter.preview(
            csvText: """
            姓名,电话
            ,13800000003
            李四,13900000003
            """,
            existing: existing
        )
        #expect(candidates.count == 1)
        #expect(candidates[0].name == "李四")
    }

    @Test("示例 CSV 场景：1 跳过、1 疑似重复、2 新增")
    func sampleCSVScenario() throws {
        let candidates = try CSVImporter.preview(csvText: CSVImporter.sampleCSV, existing: existing)
        #expect(candidates.count == 4)
        #expect(candidates.filter { $0.skip }.count == 1)
        #expect(candidates.filter { $0.suspectedDuplicate }.count == 1)
        #expect(candidates.filter { !$0.skip && !$0.suspectedDuplicate }.count == 2)
    }
}
