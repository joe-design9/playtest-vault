import SwiftUI

struct VaultView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var vaultStore: VaultStore
    @State private var editorTarget: EditorTarget?

    private enum EditorTarget: Identifiable {
        case new
        case edit(VaultEntry)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let entry): return "edit-\(entry.id.uuidString)"
            }
        }

        var entry: VaultEntry? {
            switch self {
            case .new: return nil
            case .edit(let entry): return entry
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vaultStore.entries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(store.tr("Vault", "Vault"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editorTarget = .new
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(VaultAccent.teal)
                            .font(.title3)
                    }
                }
            }
            .sheet(item: $editorTarget) { target in
                VaultEntryEditor(entry: target.entry) { saved in
                    if target.entry == nil {
                        vaultStore.add(saved)
                    } else {
                        vaultStore.update(saved)
                    }
                }
                .presentationDetents([.large])
            }
        }
    }

    private var list: some View {
        let sorted = vaultStore.sortedEntries
        return List {
            ForEach(sorted) { entry in
                Button {
                    editorTarget = .edit(entry)
                } label: {
                    VaultEntryCard(entry: entry)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        vaultStore.delete(entry)
                    } label: {
                        Label(store.tr("Löschen", "Delete"), systemImage: "trash")
                    }
                    Button {
                        editorTarget = .edit(entry)
                    } label: {
                        Label(store.tr("Bearbeiten", "Edit"), systemImage: "pencil")
                    }
                    .tint(VaultAccent.deep)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        ScrollView {
            GlassCard {
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 40))
                        .foregroundStyle(VaultAccent.teal)
                    Text(store.tr("Dein Vault ist leer", "Your vault is empty"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(store.tr(
                        "Füge Playtests aus dem Playtest-Tab und Demos hinzu oder lege oben rechts mit + deinen ersten Eintrag an.",
                        "Add playtests from the Playtest tab and Demos, or create your first entry with + at the top right."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                }
                .padding(26)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollContentBackground(.hidden)
    }
}

private struct VaultEntryCard: View {
    var entry: VaultEntry

    var body: some View {
        GlassCard(cornerRadius: 22, accent: entry.status.color) {
            VStack(alignment: .leading, spacing: 9) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                        TintedPill(text: entry.platform, color: .white)
                        TintedPill(text: entry.status.label, color: entry.status.color)
                        if let deadline = entry.deadline {
                            DeadlineChip(deadline: deadline)
                        }
                        Spacer()
                    }
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Add/edit sheet for vault entries. Keyboard dismissal is tap-outside
/// plus interactive scroll dismissal — never a toolbar Done button.
struct VaultEntryEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var entry: VaultEntry?
    var onSave: (VaultEntry) -> Void

    @State private var title: String
    @State private var platform: String
    @State private var status: VaultStatus
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var notes: String
    @FocusState private var titleFocused: Bool

    init(entry: VaultEntry?, onSave: @escaping (VaultEntry) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _title = State(initialValue: entry?.title ?? "")
        _platform = State(initialValue: entry?.platform ?? "Steam")
        _status = State(initialValue: entry?.status ?? .discovered)
        _hasDeadline = State(initialValue: entry?.deadline != nil)
        _deadline = State(initialValue: entry?.deadline ?? Date().addingTimeInterval(7 * 86400))
        _notes = State(initialValue: entry?.notes ?? "")
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    fieldCard(label: store.tr("Titel", "Title")) {
                        TextField(store.tr("Name des Playtests", "Playtest name"), text: $title)
                            .foregroundStyle(.white)
                            .tint(VaultAccent.teal)
                            .autocorrectionDisabled()
                            .focused($titleFocused)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .glassPill()
                    }

                    fieldCard(label: store.tr("Plattform", "Platform")) {
                        Picker(store.tr("Plattform", "Platform"), selection: $platform) {
                            ForEach(Platforms.all, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(VaultAccent.teal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    fieldCard(label: store.tr("Status", "Status")) {
                        Picker(store.tr("Status", "Status"), selection: $status) {
                            ForEach(VaultStatus.allCases) { s in
                                Text(s.label).tag(s)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(VaultAccent.teal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    fieldCard(label: store.tr("Frist", "Deadline")) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $hasDeadline) {
                                Text(store.tr("Frist setzen", "Set a deadline"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            .tint(VaultAccent.teal)
                            if hasDeadline {
                                DatePicker(store.tr("Frist", "Deadline"), selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .tint(VaultAccent.teal)
                                    .environment(\.locale, Lang.locale)
                            }
                        }
                    }

                    fieldCard(label: store.tr("Notizen", "Notes")) {
                        TextEditor(text: $notes)
                            .foregroundStyle(.white)
                            .tint(VaultAccent.teal)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 84)
                            .padding(10)
                            .glassPill()
                    }

                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Text(store.tr("Abbrechen", "Cancel"))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .glassPill()
                        }
                        .buttonStyle(.plain)
                        Button {
                            save()
                        } label: {
                            Text(store.tr("Speichern", "Save"))
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(canSave ? VaultAccent.teal : Color.gray.opacity(0.5)))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSave)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .background { AppBackdrop() }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { titleFocused = false }
            .navigationTitle(entry == nil ? store.tr("Neuer Eintrag", "New entry") : store.tr("Eintrag bearbeiten", "Edit entry"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func fieldCard<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(label.uppercased())
                    .font(.caption2.weight(.bold)).tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let saved = VaultEntry(
            id: entry?.id ?? UUID(),
            title: trimmed,
            platform: platform,
            source: entry?.source ?? "manual",
            status: status,
            deadline: hasDeadline ? deadline : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dateAdded: entry?.dateAdded ?? Date()
        )
        onSave(saved)
        Haptics.tap()
        dismiss()
    }
}
