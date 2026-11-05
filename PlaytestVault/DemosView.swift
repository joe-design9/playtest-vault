import SwiftUI

struct DemosView: View {
    @EnvironmentObject private var store: AppStore
    @State private var sort: DemoSort = .popular
    @State private var demos: [SteamDemo] = []
    @State private var isLoading = false
    @State private var failed = false

    /// Refetch when the sort order or the app language changes (the
    /// Steam language parameter is baked into every request).
    private var sortKey: String { "\(sort)-\(store.language)" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker(store.tr("Sortierung", "Sort"), selection: $sort) {
                        Text(store.tr("Beliebt", "Popular")).tag(DemoSort.popular)
                        Text(store.tr("Neu", "New")).tag(DemoSort.new)
                    }
                    .pickerStyle(.segmented)

                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(store.tr("Demos", "Demos"))
            .navigationBarTitleDisplayMode(.large)
            .task(id: sortKey) { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && demos.isEmpty {
            ProgressView()
                .tint(.white)
                .padding(.top, 60)
        } else if failed && demos.isEmpty {
            GlassCard {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(VaultAccent.teal)
                    Text(store.tr("Steam konnte nicht geladen werden", "Could not load Steam"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(store.tr(
                        "Die Demo-Liste kommt live vom Steam Store. Prüf deine Verbindung und versuch es erneut.",
                        "The demo list comes live from the Steam Store. Check your connection and try again."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    Button {
                        Task { await load() }
                    } label: {
                        Text(store.tr("Erneut versuchen", "Try again"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(VaultAccent.teal))
                    }
                    .buttonStyle(.plain)
                }
                .padding(22)
                .frame(maxWidth: .infinity)
            }
        } else if demos.isEmpty {
            GlassCard {
                Text(store.tr("Gerade keine Demos gefunden.", "No demos found right now."))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
        } else {
            ForEach(demos) { demo in
                NavigationLink {
                    SteamDetailView(demo: demo)
                } label: {
                    DemoRow(demo: demo)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func load() async {
        if store.uiTestMode {
            demos = SampleData.demos
            failed = false
            return
        }
        isLoading = true
        do {
            demos = try await SteamService.fetchDemos(sort: sort)
            failed = false
        } catch {
            failed = true
        }
        isLoading = false
    }
}

private struct DemoRow: View {
    var demo: SteamDemo

    var body: some View {
        GlassCard(cornerRadius: 20) {
            HStack(spacing: 14) {
                capsule
                VStack(alignment: .leading, spacing: 7) {
                    Text(demo.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    HStack {
                        TintedPill(text: "Demo", color: VaultAccent.teal)
                        TintedPill(text: "Steam", color: .white)
                        Spacer()
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(12)
        }
    }

    private var capsule: some View {
        ZStack {
            CoverArt(title: demo.title, height: 48)
            if demo.demoAppID > 0, let url = demo.capsuleURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .frame(width: 118, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
