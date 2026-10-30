import SwiftUI
import UniformTypeIdentifiers
import PeoplebookKit

/// 导入预览 sheet（GLOSSARY：导入预览 / 跳过 / 疑似重复）。
struct ImportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var candidates: [CSVImporter.Candidate] = []
    @State private var errorMessage: String?
    @State private var showingFileImporter = false

    private var importCount: Int {
        candidates.filter { !$0.skip }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 680, minHeight: 480)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
            allowsMultipleSelection: false
        ) { result in
            load(from: result)
        }
    }

    // MARK: - 区块

    @ViewBuilder private var header: some View {
        HStack {
            Text("导入预览")
                .font(.headline)
            Text("UTF-8 CSV · 首行表头")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                showingFileImporter = true
            } label: {
                Label("选择 CSV 文件…", systemImage: "doc.text")
            }
            Button {
                loadCSV(CSVImporter.sampleCSV)
            } label: {
                Label("示例 CSV", systemImage: "sparkles")
            }
            .help("填入内置示例（含跳过与疑似重复场景）")
        }
        .padding(12)

        if let errorMessage {
            Text(errorMessage)
                .font(.callout)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder private var content: some View {
        if candidates.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("选择一个 UTF-8 CSV 文件，或点击「示例 CSV」体验流程")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(candidates) { candidate in
                    candidateRow(candidate)
                }
            }
            .listStyle(.inset)
        }
    }

    private func candidateRow(_ candidate: CSVImporter.Candidate) -> some View {
        HStack(spacing: 14) {
            Toggle(isOn: skipBinding(candidate)) {
                HStack(spacing: 4) {
                    Text(candidate.name)
                        .font(.callout.weight(.medium))
                    if !candidate.title.isEmpty {
                        Text(candidate.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minWidth: 180, alignment: .leading)

            if !candidate.company.isEmpty {
                Text(candidate.company)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 90, alignment: .leading)
            }

            if !candidate.phone.isEmpty {
                Text(candidate.phone)
                    .font(.caption.monospacedDigit())
            }

            Spacer(minLength: 8)

            if candidate.suspectedDuplicate {
                Text("疑似重复")
                    .font(.caption)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.2), in: Capsule())
                    .foregroundStyle(.orange)
                    .help("已有同名联系人但电话不同；默认仍导入，可取消勾选")
            }
        }
        .padding(.vertical, 3)
    }

    private var footer: some View {
        HStack {
            Text(
                "共 \(candidates.count) 行 · 将导入 \(importCount) · 跳过 \(candidates.count - importCount)"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
            Button("取消") {
                reset()
                dismiss()
            }
            Button {
                model.importCandidates(candidates)
                reset()
                dismiss()
            } label: {
                Label("导入所选 \(importCount) 条", systemImage: "tray.and.arrow.down.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(candidates.isEmpty || importCount == 0)
        }
        .padding(12)
    }

    // MARK: - 逻辑

    private func skipBinding(_ candidate: CSVImporter.Candidate) -> Binding<Bool> {
        Binding(
            get: { !candidate.skip },
            set: { willImport in
                setSkip(candidate, skip: !willImport)
            }
        )
    }

    private func setSkip(_ candidate: CSVImporter.Candidate, skip: Bool) {
        guard let index = candidates.firstIndex(where: { $0.id == candidate.id }) else { return }
        candidates[index].skip = skip
    }

    private func load(from result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                loadCSV(try CSVImporter.decode(data))
            } catch {
                errorMessage = "读取文件失败：\(error.localizedDescription)"
                candidates = []
            }
        case .failure(let error):
            errorMessage = "选择文件失败：\(error.localizedDescription)"
        }
    }

    private func loadCSV(_ decoded: String) {
        do {
            errorMessage = nil
            candidates = try CSVImporter.preview(csvText: decoded, existing: model.contacts)
        } catch CSVImporter.ImportError.emptyFile {
            errorMessage = "CSV 里没有数据行。"
            candidates = []
        } catch CSVImporter.ImportError.missingHeader {
            errorMessage = "未能解析表头行。"
            candidates = []
        } catch CSVImporter.ImportError.missingNameColumn {
            errorMessage = "表头缺少「姓名」列（必须有：姓名、电话、邮箱、公司、职位）。"
            candidates = []
        } catch {
            errorMessage = "导入失败：\(error)"
            candidates = []
        }
    }

    private func reset() {
        candidates = []
        errorMessage = nil
    }
}
