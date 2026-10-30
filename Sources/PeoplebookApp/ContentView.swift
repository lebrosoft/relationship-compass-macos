import SwiftUI
import PeoplebookKit

// MARK: - 根视图（规格「Implementation Decisions」：搜索框+列表 / 详情）

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            ContactListPane()
        } detail: {
            ContactDetailPane()
        }
        .sheet(isPresented: $model.importing) {
            ImportSheet()
        }
        .alert("操作失败", isPresented: actionErrorBinding) {
            Button("知道了") {}
        } message: {
            Text(model.actionErrorMessage ?? "")
        }
        .alert("本地数据库不可用", isPresented: persistenceWarningBinding) {
            Button("知道了") {}
        } message: {
            Text(model.persistenceWarning ?? "")
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { model.actionErrorMessage != nil },
            set: { _ in model.clearActionError() }
        )
    }

    private var persistenceWarningBinding: Binding<Bool> {
        Binding(
            get: { model.persistenceWarning != nil },
            set: { _ in model.clearPersistenceWarning() }
        )
    }
}

// MARK: - 左栏：搜索 + 联系人列表（逾期者红点、右键删除）

struct ContactListPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selection) {
            ForEach(model.searchResults) { result in
                listRow(result)
            }
        }
        .overlay {
            if model.searchResults.isEmpty {
                ContentUnavailableView.search(text: model.query)
            }
        }
        .searchable(
            text: $model.query,
            placement: .sidebar,
            prompt: "姓名、公司、职位、备注或互动笔记"
        )
        .navigationTitle("人脉簿")
        .toolbar {
            Button {
                model.importing = true
            } label: {
                Label("导入 CSV", systemImage: "square.and.arrow.down")
            }
        }
    }

    private func listRow(_ result: SearchResult) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.contact.name)
                    .font(.headline)
                let subtitle = [result.contact.company, result.contact.title]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if model.isOverdue(result.contact) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .help("距上次互动已超过该层级的提醒阈值")
            }
        }
        .tag(result.contact.id)
        .contextMenu {
            Button(role: .destructive) {
                model.deleteContact(result.contact)
            } label: {
                Label("删除联系人", systemImage: "trash")
            }
        }
    }
}
