import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedStore: FeedStore
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [PlaytestItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return feedStore.items }
        return feedStore.items.filter { item in
            item.title.lowercased().contains(q)
                || item.platform.lowercased().contains(q)
                || item.tags.contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    searchField
                    if let updated = feedStore.feedUpdated {
                        HStack {
                            Text(store.tr("Stand: ", "Updated: ") + updated.formatted(.dateTime.day().month().year().locale(Lang.locale)))
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.45))
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { searchFocused = false }
            .refreshable { await feedStore.refresh() }
            .navigationTitle(store.tr("Entdecken", "Discover"))
            .navigationBarTitleDisplayMode(.large)
            .task { await feedStore.loadIfNeeded() }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.55))
                .font(.subheadline.weight(.semibold))
            TextField(store.tr("Playtest oder Tag suchen", "Search playtest or tag"), text: $query)
                .foregroundStyle(.white)
                .tint(VaultAccent.teal)
                .autocorrectionDisabled()
                .focused($searchFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassPill()
    }

    @ViewBuilder
    private var content: some View {
        if feedStore.items.isEmpty && feedStore.isLoading {
            ProgressView()
                .tint(.white)
                .padding(.top, 60)
        } else if feedStore.items.isEmpty {
            GlassCard {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .font(.title)
                        .foregroundStyle(VaultAccent.teal)
                    Text(store.tr("Feed konnte nicht geladen werden", "Could not load the feed"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(store.tr(
                        "Prüf deine Verbindung und zieh die Liste nach unten, um es erneut zu versuchen.",
                        "Check your connection and pull down to try again."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                }
                .padding(22)
                .frame(maxWidth: .infinity)
            }
        } else if filtered.isEmpty {
            GlassCard {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(VaultAccent.teal)
                    Text(store.tr("Keine Treffer für deine Suche", "No results for your search"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
        } else {
            ForEach(filtered) { item in
                NavigationLink {
                    PlaytestDetailView(item: item)
                } label: {
                    PlaytestCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Feed status wording to pill color.
func feedStatusColor(_ status: String) -> Color {
    switch status {
    case "Live now": return Color(red: 0.35, green: 0.85, blue: 0.45)
    case "Signups open": return Color(red: 0.35, green: 0.65, blue: 1.0)
    case "Coming soon": return Color(red: 0.70, green: 0.50, blue: 1.0)
    case "Ended": return Color(red: 0.62, green: 0.62, blue: 0.66)
    default: return VaultAccent.teal
    }
}

private struct PlaytestCard: View {
    var item: PlaytestItem

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                CoverImage(url: item.imageURL, title: item.title, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(10)
                VStack(alignment: .leading, spacing: 9) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                            TintedPill(text: item.platform, color: .white)
                            TintedPill(text: item.status, color: feedStatusColor(item.status))
                            if let deadline = item.deadline {
                                DeadlineChip(deadline: deadline)
                            }
                            Spacer()
                        }
                    if !item.tags.isEmpty {
                        Text(item.tags.map { "#\($0)" }.joined(separator: "  "))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}
