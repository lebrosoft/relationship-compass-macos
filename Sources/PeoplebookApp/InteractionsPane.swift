import SwiftUI
import PeoplebookKit

// MARK: - 中栏：互动时间线 + 新增互动

struct InteractionsPane: View {
    @Environment(AppModel.self) private var model

    @State private var draftKind: InteractionKind = .coffeeFaceToFace
    @State private var draftDate = Date()
    @State private var draftNote = ""

    private var contact: Contact? { model.selectedContact }

    var body: some View {
        Group {
            if let contact {
                VStack(spacing: 0) {
                    interactionsHeader(contact)
                    Divider()
                    if model.isOverdue(contact) {
                        overdueBanner(contact)
                        Divider()
                    }
                    interactionList(contact)
                }
            } else {
                ContentUnavailableView(
                    "尚未选择联系人",
                    systemImage: "person.crop.circle",
                    description: Text("在左侧列表中选择一位联系人，查看互动时间线")
                )
            }
        }
        .frame(minWidth: 320)
    }

    private func interactionsHeader(_ contact: Contact) -> some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
            Text("互动时间线")
                .font(.headline)
            Spacer()
            Text("\(model.interactions(of: contact.id).count) 条")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func overdueBanner(_ contact: Contact) -> some View {
        let days = Reminder.daysSince(
            Reminder.lastInteractionDate(model.interactions(of: contact.id)) ?? Date(),
            to: .now
        ) ?? 0
        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("距上次互动已 \(days) 天（阈值 \(contact.level.reminderDays ?? 0) 天）")
                .font(.subheadline)
            Text("该主动联系一下了")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .foregroundStyle(.red)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.red.opacity(0.06))
    }

    private func interactionList(_ contact: Contact) -> some View {
        List {
            ForEach(model.interactions(of: contact.id)) { interaction in
                interactionRow(contact, interaction)
            }
        }
        .listStyle(.inset)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            addInteractionBar(contact)
        }
    }

    private func interactionRow(_ contact: Contact, _ interaction: Interaction) -> some View {
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

    private func addInteractionBar(_ contact: Contact) -> some View {
        HStack(spacing: 8) {
            Picker("类型", selection: $draftKind) {
                ForEach(InteractionKind.allCases, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .labelsHidden()
            .fixedSize()

            DatePicker("日期", selection: $draftDate)
                .labelsHidden()
                .datePickerStyle(.compact)

            TextField("笔记（可留空）", text: $draftNote)
                .textFieldStyle(.roundedBorder)

            Button {
                model.addInteraction(
                    Interaction(
                        contactID: contact.id,
                        kind: draftKind,
                        date: draftDate,
                        note: draftNote
                    )
                )
                draftNote = ""
            } label: {
                Label("添加互动", systemImage: "plus")
            }
        }
        .padding(10)
        .background(.bar)
    }
}
