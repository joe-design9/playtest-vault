import SwiftUI

/// Shared detail for Discover feed items: big cover, glass info card
/// with a live deadline countdown, description and vault action.
struct PlaytestDetailView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var vaultStore: VaultStore
    @Environment(\.openURL) private var openURL
    var item: PlaytestItem

    private var inVault: Bool { vaultStore.contains(title: item.title) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CoverImage(url: item.imageURL, title: item.title, height: 210, accent: item.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text(item.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                infoCard

                Text(item.description)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(3)

                if !item.tags.isEmpty {
                    Text(item.tags.map { "#\($0)" }.joined(separator: "  "))
                        .font(.caption)
                        .foregroundStyle(item.accentColor.opacity(0.75))
                }

                actions
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background { AppBackdrop() }
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var infoCard: some View {
        GlassCard(accent: item.accentColor) {
            VStack(spacing: 0) {
                infoRow(label: store.tr("Plattform", "Platform"), value: item.platform)
                Divider().overlay(Color.white.opacity(0.12))
                HStack {
                    Text(store.tr("Status", "Status"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    TintedPill(text: item.status, color: feedStatusColor(item.status))
                }
                .padding(.vertical, 12)
                if let deadline = item.deadline {
                    Divider().overlay(Color.white.opacity(0.12))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.tr("Frist", "Deadline"))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                        TimelineView(.periodic(from: Date(), by: 60)) { context in
                            Text(Countdown.detailText(deadline: deadline, now: context.date))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Countdown.isUrgent(deadline: deadline, now: context.date) ? .red : .white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 4)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 12)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let url = item.pageURL {
                Button {
                    openURL(url)
                } label: {
                    HStack {
                        Image(systemName: "safari")
                        Text(store.tr("Seite öffnen", "Open page"))
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(item.accentColor))
                }
                .buttonStyle(.plain)
            }
            Button {
                if vaultStore.addFromDiscover(item) { Haptics.tap() }
            } label: {
                HStack {
                    Image(systemName: inVault ? "checkmark.circle.fill" : "archivebox.fill")
                    Text(inVault ? store.tr("Im Vault", "In Vault") : store.tr("Zum Vault hinzufügen", "Add to Vault"))
                }
                .font(.headline)
                .foregroundStyle(inVault ? VaultAccent.teal : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassPill()
            }
            .buttonStyle(.plain)
            .disabled(inVault)
        }
        .padding(.top, 4)
    }
}
