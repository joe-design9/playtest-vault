import SwiftUI

/// Demo detail: loads the full game's appdetails from Steam (header,
/// short description, genres, release date) and links out to the
/// demo's own store page.
struct SteamDetailView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var vaultStore: VaultStore
    @Environment(\.openURL) private var openURL
    var demo: SteamDemo

    @State private var details: SteamGameDetails?
    @State private var isLoading = false
    @State private var failed = false

    private var inVault: Bool { vaultStore.contains(title: demo.title) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Text(details?.name ?? demo.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background { AppBackdrop() }
        .scrollContentBackground(.hidden)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var header: some View {
        ZStack {
            CoverArt(title: demo.title, height: 190)
            if let imageURL = details?.headerImage ?? demo.imageURL ?? (demo.demoAppID > 0 ? demo.headerURL : nil) {
                RemoteImage(url: imageURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipped()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && details == nil {
            HStack {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            }
            .padding(.top, 24)
        } else if failed && details == nil {
            GlassCard {
                VStack(spacing: 12) {
                    Text(store.tr("Details konnten nicht geladen werden", "Could not load details"))
                        .font(.headline)
                        .foregroundStyle(.white)
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
        } else if let details {
            if !details.genres.isEmpty {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(details.genres.prefix(4), id: \.self) { genre in
                            TintedPill(text: genre, color: .white)
                        }
                        Spacer()
                    }
                }
            }
            if !details.releaseDate.isEmpty {
                GlassCard {
                    HStack {
                        Text(store.tr("Release", "Release"))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                        Spacer()
                        Text(details.releaseDate)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                }
            }
            if !details.shortDescription.isEmpty {
                Text(details.shortDescription)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(3)
            }
            actions
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if demo.demoAppID > 0, let url = demo.storeURL {
                Button {
                    openURL(url)
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.forward.square")
                        Text(store.tr("Steam-Seite öffnen", "Open Steam page"))
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(VaultAccent.teal))
                }
                .buttonStyle(.plain)
            }
            Button {
                if vaultStore.addFromDemo(demo) { Haptics.tap() }
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

    private func load() async {
        if store.uiTestMode || demo.fullGameID < 0 {
            details = SampleData.sampleDetails
            failed = false
            return
        }
        isLoading = true
        do {
            details = try await SteamService.fetchDetails(fullGameID: demo.fullGameID)
            failed = false
        } catch {
            failed = true
        }
        isLoading = false
    }
}
