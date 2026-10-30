import SwiftUI
import PeoplebookKit

// MARK: - 根视图（三栏：搜索+列表 / 互动时间线 / 联系人资料）

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            ContactListPane()
        } content: {
            ContentUnavailableView(
                "互动时间线",
                systemImage: "clock.arrow.circlepath",
                description: Text("选择联系人后展示互动时间线")
            )
        } detail: {
            ContentUnavailableView(
                "联系人资料",
                systemImage: "person.crop.circle",
                description: Text("选择联系人后展示资料与关系")
            )
        }
    }
}

// MARK: - 左栏：搜索 + 联系人列表（逾期者红点）

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
    }
}
