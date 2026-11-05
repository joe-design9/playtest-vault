import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedStore: FeedStore
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [PlaytestItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base: [PlaytestItem]
        if q.isEmpty {
            base = feedStore.items
        } else {
            base = feedStore.items.filter { item in
                item.title.lowercased().contains(q)
                    || item.platform.lowercased().contains(q)
                    || item.tags.contains { $0.lowercased().contains(q) }
            }
        }
        return base.sorted(by: Self.feedOrder)
    }

    /// Live tests first, then open sign-ups, coming soon, ended last;
    /// inside a group the nearest deadline wins.
    private static func feedOrder(_ a: PlaytestItem, _ b: PlaytestItem) -> Bool {
        let ra = statusRank(a.status), rb = statusRank(b.status)
        if ra != rb { return ra < rb }
        switch (a.deadline, b.deadline) {
        case let (da?, db?): return da < db
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return a.title < b.title
        }
    }

    private static func statusRank(_ status: String) -> Int {
        switch status {
        case "Live now": return 0
        case "Signups open": return 1
        case "Coming soon": return 2
        case "Ended": return 3
        default: return 1
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    searchField
                    if !feedStore.items.isEmpty {
                        heroHeader
                    }
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
            .navigationTitle(store.tr("Playtest", "Playtest"))
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

    /// Living summary card at the top of the Playtest tab: how many
    /// tests are live right now, how many sign-ups are open and when
    /// the next deadline hits.
    private var heroHeader: some View {
        let live = feedStore.items.filter { $0.status == "Live now" }.count
        let open = feedStore.items.filter { $0.status == "Signups open" }.count
        let next = feedStore.items.compactMap { $0.deadline }.filter { $0 > Date() }.min()
        return GlassCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(VaultAccent.gradient)
                        .frame(width: 52, height: 52)
                    Image(systemName: "gamecontroller.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.tr("\(live) Playtests laufen gerade", "\(live) playtests live right now"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(heroSubline(open: open, next: next))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private func heroSubline(open: Int, next: Date?) -> String {
        var parts: [String] = []
        if open > 0 {
            parts.append(store.tr("\(open) Anmeldungen offen", "\(open) sign-ups open"))
        }
        if let next {
            parts.append(store.tr("Nächste Frist: ", "Next deadline: ") + Countdown.chipText(deadline: next))
        }
        return parts.joined(separator: " \u{00B7} ")
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
                        .opacity(item.status == "Ended" ? 0.72 : 1)
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
