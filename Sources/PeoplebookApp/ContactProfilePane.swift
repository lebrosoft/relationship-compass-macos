import SwiftUI
import PeoplebookKit

// MARK: - 右栏：资料 + 关系

struct ContactProfilePane: View {
    @Environment(AppModel.self) private var model

    @State private var draft = Contact(name: "")
    @State private var newConnectionID: UUID?
    @State private var newConnectionKind: RelationshipKind = .friend

    private var contact: Contact? { model.selectedContact }

    var body: some View {
        Group {
            if let contact {
                profile(for: contact)
                    .task(id: contact.id) {
                        draft = contact
                        if newConnectionID == contact.id { newConnectionID = nil }
                    }
            } else {
                ContentUnavailableView(
                    "尚未选择联系人",
                    systemImage: "person.crop.circle.dashed",
                    description: Text("右侧展示联系人的资料与人脉关系")
                )
            }
        }
        .frame(minWidth: 380)
    }

    private func profile(for contact: Contact) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                profileCard(contact)
                relationshipCard(contact)
            }
            .padding(20)
        }
    }

    private func profileCard(_ contact: Contact) -> some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("姓名").foregroundStyle(.secondary)
                    TextField("姓名", text: $draft.name)
                }
                GridRow {
                    Text("层级").foregroundStyle(.secondary)
                    Picker("层级", selection: $draft.level) {
                        ForEach(Level.allCases, id: \.self) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .fixedSize()
                }
                GridRow {
                    Text("电话").foregroundStyle(.secondary)
                    TextField("电话", text: $draft.phone)
                }
                GridRow {
                    Text("邮箱").foregroundStyle(.secondary)
                    TextField("邮箱", text: $draft.email)
                }
                GridRow {
                    Text("公司").foregroundStyle(.secondary)
                    TextField("公司", text: $draft.company)
                }
                GridRow {
                    Text("职位").foregroundStyle(.secondary)
                    TextField("职位", text: $draft.title)
                }
                GridRow(alignment: .top) {
                    Text("备注").foregroundStyle(.secondary)
                    TextEditor(text: $draft.note)
                        .frame(minHeight: 76)
                        .scrollContentBackground(.hidden)
                }
            }
            .padding(6)

            HStack {
                Spacer()
                if draft != contact {
                    Text("有未保存的修改")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    model.saveContact(draft)
                } label: {
                    Label("保存资料", systemImage: "checkmark.circle")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(draft == contact)
            }
        } label: {
            HStack(spacing: 8) {
                Text(contact.name)
                    .font(.title3.weight(.semibold))
                if model.isOverdue(contact) {
                    Circle().fill(.red).frame(width: 9, height: 9)
                        .help("该维护这段关系了")
                }
                Spacer()
                Text(contact.level.label)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(levelColor(contact.level).opacity(0.18), in: Capsule())
                    .foregroundStyle(levelColor(contact.level))
            }
        }
    }

    private func levelColor(_ level: Level) -> Color {
        switch level {
        case .key: .red
        case .normal: .blue
        case .cold: .gray
        }
    }

    private var otherContacts: [Contact] {
        (model.selectedContact.map { contact in
            model.contacts.filter { $0.id != contact.id }
        }) ?? []
    }

    private func relationshipCard(_ contact: Contact) -> some View {
        let edges = model.relationships(of: contact.id)
        return GroupBox {
            if edges.isEmpty {
                Text("还没有与他人的关系连线")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(edges) { edge in
                    HStack {
                        Image(systemName: "arrow.left.and.right.rectangle")
                            .foregroundStyle(.secondary)
                        let other = model.contact(id: otherID(edge, of: contact.id))
                        Text("\(other?.name ?? "未知联系人") — \(edge.kind.label)")
                            .font(.callout)
                        Spacer(minLength: 8)
                        Button {
                            model.deleteRelationship(edge)
                        } label: {
                            Image(systemName: "trash").font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            Divider()
            HStack(spacing: 8) {
                Picker("另一端", selection: $newConnectionID) {
                    Text("选择联系人…").tag(UUID?.none)
                    ForEach(otherContacts) { other in
                        Text(other.name).tag(UUID?.some(other.id))
                    }
                }
                .frame(maxWidth: 180)
                .fixedSize()
                .pickerStyle(.menu)

                Picker("关系", selection: $newConnectionKind) {
                    ForEach(RelationshipKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .fixedSize()
                .pickerStyle(.menu)

                Spacer()

                Button {
                    if let target = newConnectionID, target != contact.id {
                        model.addRelationship(
                            first: contact.id, second: target, kind: newConnectionKind
                        )
                        newConnectionID = nil
                    }
                } label: {
                    Label("连线", systemImage: "link")
                }
                .disabled(newConnectionID == nil)
            }
        } label: {
            Text("联系人间关系")
                .font(.headline)
        }
    }

    private func otherID(_ relationship: Relationship, of contactID: UUID) -> UUID {
        relationship.firstContactID == contactID
            ? relationship.secondContactID
            : relationship.firstContactID
    }
}
