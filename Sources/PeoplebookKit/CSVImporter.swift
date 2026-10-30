import Foundation

/// CSV 导入域规则（GLOSSARY「导入预览 / 跳过 / 疑似重复」）：
/// UTF-8、逗号分隔、首行表头，列：姓名、电话、邮箱、公司、职位。
/// 姓名缺失列 → 报错；行内姓名为空 → 忽略该行。
public enum CSVImporter {

    public enum ImportError: Error, Equatable, Sendable {
        /// 没有找到「姓名」表头列
        case missingNameColumn
        /// 没有有效表头（首行为空）
        case missingHeader
        /// 没有任何数据行
        case emptyFile
        /// 无法解码（非法 UTF-8 且无法修复，或文件为空）
        case undecodable
    }

    public struct ParsedCSV: Equatable, Sendable {
        public var header: [String]
        public var rows: [[String]]
    }

    /// 导入预览中的一行候选。
    public struct Candidate: Identifiable, Hashable, Sendable {
        public var id: UUID
        public var name: String
        public var phone: String
        public var email: String
        public var company: String
        public var title: String
        /// 姓名与电话同时命中 → 预览默认勾选跳过。
        public var skip: Bool
        /// 仅姓名命中 → 疑似重复，默认仍导入。
        public var suspectedDuplicate: Bool

        public init(
            id: UUID = UUID(),
            name: String,
            phone: String = "",
            email: String = "",
            company: String = "",
            title: String = "",
            skip: Bool = false,
            suspectedDuplicate: Bool = false
        ) {
            self.id = id
            self.name = name
            self.phone = phone
            self.email = email
            self.company = company
            self.title = title
            self.skip = skip
            self.suspectedDuplicate = suspectedDuplicate
        }

        /// 生成联系人（导入时调用）。
        public func makeContact() -> Contact {
            Contact(
                name: name,
                phone: phone,
                email: email,
                company: company,
                title: title
            )
        }
    }

    // MARK: - 解析

    public static func decode(_ data: Data) throws -> String {
        // 去 BOM；Phone/Excel 导出的 UTF-8 常带 BOM。
        var payload = data
        if payload.starts(with: [0xEF, 0xBB, 0xBF]) {
            payload = payload.dropFirst(3)
        }
        guard !payload.isEmpty else { throw ImportError.undecodable }
        return String(decoding: payload, as: UTF8.self)
    }

    public static func parse(_ text: String) throws -> ParsedCSV {
        let grid = parseGrid(text)
        guard !grid.isEmpty else { throw ImportError.missingHeader }
        let header = normalizeHeader(grid[0])
        guard !header.isEmpty else { throw ImportError.missingHeader }
        guard header.contains("姓名") else { throw ImportError.missingNameColumn }
        guard grid.count > 1 else { throw ImportError.emptyFile }
        return ParsedCSV(header: header, rows: Array(grid.dropFirst()))
    }

    /// 预置体验用示例 CSV（导入 sheet 可一键填入）：4 行中
    /// 1 个跳过（陈志远）、1 个疑似重复（王芳）、2 个新增。
    public static let sampleCSV = """
    姓名,电话,邮箱,公司,职位
    陈志远,13800000001,chen.zhiyuan@example.com,云帆科技,技术合伙人
    王芳,,wang.fang@example.com,青竹资本,投资总监
    周雨桐,13300000011,zhou.yutong@example.com,拾光影像,摄影师
    何立群,,he.liqun@example.com,三和咨询,合伙人
    """

    // MARK: - 预览

    /// 由 CSV 文本和现有联系人生成导入预览。
    /// - 姓名命中 + 电话命中 → skip = true
    /// - 姓名命中 + 电话不命中 → suspectedDuplicate = true（默认仍导入）
    public static func preview(csvText: String, existing: [Contact]) throws -> [Candidate] {
        let parsed = try parse(csvText)
        let column = try columnMap(header: parsed.header)
        let existingNames = Set(existing.map { normalized(name: $0.name) })
        let existingPhones = Set(existing.map { normalized(phone: $0.phone) })

        return parsed.rows.compactMap { row -> Candidate? in
            let name = normalized(name: value(of: row, at: column.name))
            guard !name.isEmpty else { return nil }
            let phone = normalized(phone: value(of: row, at: column.phone))
            let nameHit = existingNames.contains(name)
            let phoneHit = !phone.isEmpty && existingPhones.contains(phone)
            return Candidate(
                name: name,
                phone: phone,
                email: value(of: row, at: column.email),
                company: value(of: row, at: column.company),
                title: value(of: row, at: column.title),
                skip: nameHit && phoneHit,
                suspectedDuplicate: nameHit && !phoneHit
            )
        }
    }

    struct ColumnMap: Sendable {
        var name: Int
        var phone: Int = -1
        var email: Int = -1
        var company: Int = -1
        var title: Int = -1
    }

    private static func columnMap(header: [String]) throws -> ColumnMap {
        guard let name = header.firstIndex(of: "姓名") else {
            throw ImportError.missingNameColumn
        }
        func indexOf(_ names: [String]) -> Int {
            for name in names {
                if let i = header.firstIndex(of: name) { return i }
            }
            return -1
        }
        return ColumnMap(
            name: name,
            phone: indexOf(["电话", "手机", "手机号", "电话号码"]),
            email: indexOf(["邮箱", "电子邮件", "Email", "邮件"]),
            company: indexOf(["公司", "单位"]),
            title: indexOf(["职位", "职务", "头衔"])
        )
    }

    private static func value(of row: [String], at index: Int) -> String {
        guard index >= 0, index < row.count else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalized(name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 电话归一化：仅保留数字，忽略空格、横线、国家码 +86。
    private static func normalized(phone: String) -> String {
        let digits = phone.filter(\.isNumber)
        if digits.count > 10, digits.hasPrefix("86"), digits.count >= 11 {
            return String(digits.dropFirst(2))
        }
        return digits
    }

    private static func normalizeHeader(_ row: [String]) -> [String] {
        row.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(["\u{FEFF}"]))
        }
    }

    // MARK: - RFC4180 风格拆分（支持引号内的逗号、换行、转义引号）

    static func parseGrid(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var fieldHasContent = false

        // 逐 Unicode scalar 处理：Swift 字符串里 "\r\n" 是单个字素簇，
        // 按字素切分就再也匹配不到单独的 \r / \n 了。
        let scalars = Array(text.unicodeScalars)
        var i = 0
        func endField() {
            row.append(field)
            field = ""
            fieldHasContent = false
        }
        func endRow() {
            endField()
            rows.append(row)
            row = []
        }

        while i < scalars.count {
            let c = scalars[i]
            if inQuotes {
                if c == "\"" {
                    let escaped = i + 1 < scalars.count && scalars[i + 1] == "\""
                    if escaped { field.unicodeScalars.append("\""); i += 2 } else { inQuotes = false; i += 1 }
                } else {
                    field.unicodeScalars.append(c)
                    fieldHasContent = true
                    i += 1
                }
            } else if c == "\"" {
                inQuotes = true
                i += 1
            } else if c == "," {
                endField()
                i += 1
            } else if c == "\n" || c == "\r" {
                if c == "\r", i + 1 < scalars.count, scalars[i + 1] == "\n" { i += 1 }
                endRow()
                i += 1
            } else {
                field.unicodeScalars.append(c)
                fieldHasContent = true
                i += 1
            }
        }
        // 文件末尾没有换行：收尾最后一个 field
        if fieldHasContent || !field.isEmpty || !row.isEmpty {
            endRow()
        }
        // 去掉结尾的空行（grid split 产生的假行）
        while let last = rows.last, last == [""], rows.count > 1 {
            rows.removeLast()
        }
        return rows
    }
}
