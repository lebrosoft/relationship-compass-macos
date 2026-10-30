import SwiftUI
import PeoplebookKit

// MARK: - 详情栏：资料（层级/备注编辑）+ 互动时间线 + 联系人间关系

struct ContactDetailPane: View {
    @Environment(AppModel.self) private var model

    @State private var draft = Contact(name: "")
    @State private var newRelationshipID: UUID?
    @State private var newRelationshipKind: RelationshipKind = .friend
    @State private var interactionKind: InteractionKind = .coffeeFaceToFace
    @State private var interactionDate = Date()
    @State private var interactionNote = ""

    private var contact: Contact? { model.selectedContact }

    var body: some View {
        Group {
            if let contact {
                detail(for: contact)
                    .task(id: contact.id) {
                        draft = contact
                        if newRelationshipID == contact.id { newRelationshipID = nil }
                    }
            } else {
                ContentUnavailableView(
                    "尚未选择联系人",
                    systemImage: "person.crop.circle.dashed",
                    description: Text("在左侧列表中选择一位联系人：资料、互动与人脉关系都在这里")
                )
            }
        }
        .frame(minWidth: 440)
    }

    private func detail(for contact: Contact) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                profileCard(contact)
                interactionsSection(contact)
                relationshipsSection(contact)
            }
            .padding(20)
        }
    }

    // MARK: 资料卡

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

    // MARK: 互动时间线

    private func interactionsSection(_ contact: Contact) -> some View {
        GroupBox {
            if model.isOverdue(contact) {
                overdueBanner(contact)
            }
            if model.interactions(of: contact.id).isEmpty {
                Text("还没有互动记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(model.interactions(of: contact.id)) { interaction in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(interaction.kind.label)
                                    .font(.subheadline.weight(.medium))
                                Text(interaction.date, format: .dateTime.year().month().day())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !interaction.note.isEmpty {
                                Text(interaction.note)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 8)
                        Button {
                            model.deleteInteraction(interaction)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            Divider()
            HStack(spacing: 8) {
                Picker("类型", selection: $interactionKind) {
                    ForEach(InteractionKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .labelsHidden()
                .fixedSize()

                DatePicker("日期", selection: $interactionDate)
                    .labelsHidden()
                    .datePickerStyle(.compact)

                TextField("笔记（可留空）", text: $interactionNote)
                    .textFieldStyle(.roundedBorder)

                Button {
                    model.addInteraction(
                        Interaction(
                            contactID: contact.id,
                            kind: interactionKind,
                            date: interactionDate,
                            note: interactionNote
                        )
                    )
                    interactionNote = ""
                } label: {
                    Label("添加互动", systemImage: "plus")
                }
            }
        } label: {
            HStack {
                Text("互动时间线")
                    .font(.headline)
                Spacer()
                Text("\(model.interactions(of: contact.id).count) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func overdueBanner(_ contact: Contact) -> some View {
        let days = Reminder.daysSince(
            Reminder.lastInteractionDate(model.interactions(of: contact.id)) ?? Date(),
            to: .now
        ) ?? 0
        let threshold = contact.level.reminderDays.map { "（阈值 \($0) 天）" } ?? ""
        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("距上次互动已 \(days) 天 \(threshold)")
                .font(.subheadline)
            Text("该主动联系一下了")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .foregroundStyle(.red)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: 联系人间关系

    private var otherContacts: [Contact] {
        (contact.map { member in
            model.contacts.filter { $0.id != member.id }
        }) ?? []
    }

    private func relationshipsSection(_ contact: Contact) -> some View {
        let edges = model.relationships(of: contact.id)
        return GroupBox {
            if edges.isEmpty {
                Text("还没有任何联系人间关系")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(edges) { edge in
                    HStack {
                        Image(systemName: "arrow.left.and.right.rectangle")
                            .foregroundStyle(.secondary)
                        let other = model.contact(id: edge.otherEndpoint(of: contact.id))
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
                Picker("另一端", selection: $newRelationshipID) {
                    Text("选择联系人…").tag(UUID?.none)
                    ForEach(otherContacts) { other in
                        Text(other.name).tag(UUID?.some(other.id))
                    }
                }
                .frame(maxWidth: 180)
                .fixedSize()
                .pickerStyle(.menu)

                Picker("关系", selection: $newRelationshipKind) {
                    ForEach(RelationshipKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .fixedSize()
                .pickerStyle(.menu)

                Spacer()

                Button {
                    if let target = newRelationshipID, target != contact.id {
                        model.addRelationship(
                            first: contact.id, second: target, kind: newRelationshipKind
                        )
                        newRelationshipID = nil
                    }
                } label: {
                    Label("添加关系", systemImage: "link")
                }
                .disabled(newRelationshipID == nil)
            }
        } label: {
            Text("联系人间关系")
                .font(.headline)
        }
    }
}
