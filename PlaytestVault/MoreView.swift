import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    languageCard
                    sourcesCard
                    aboutCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(store.tr("Mehr", "More"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Language

    private var languageCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.tr("SPRACHE", "LANGUAGE"))
                    .font(.caption2.weight(.bold)).tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 10) {
                    languagePill(title: "Deutsch", code: "de_DE")
                    languagePill(title: "English", code: "en_US")
                    Spacer()
                }
                Text(store.tr(
                    "Gilt für die ganze App — auch Feed und Steam-Demos laden dann in der gewählten Sprache.",
                    "Applies to the whole app — the feed and Steam demos reload in the selected language too."
                ))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func languagePill(title: String, code: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { store.setLanguage(code) }
            Haptics.tap()
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(store.language == code ? .black : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background {
                    if store.language == code {
                        Capsule().fill(VaultAccent.gradient)
                    } else {
                        Capsule()
                            .fill(.clear)
                            .glassEffect(.regular.tint(.white.opacity(0.08)), in: Capsule())
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data sources

    private var sourcesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(store.tr("DATENQUELLEN", "DATA SOURCES"))
                    .font(.caption2.weight(.bold)).tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))
                sourceRow(
                    icon: "safari",
                    title: store.tr("Entdecken-Feed", "Discover feed"),
                    note: store.tr(
                        "Kuratierte Playtests aus der playtests.json (GitHub). Lädt beim Start, aktualisiert per Nach-unten-Ziehen und bleibt offline aus dem Cache lesbar.",
                        "Curated playtests from playtests.json (GitHub). Loads at launch, refreshes via pull-to-refresh and stays readable offline from the cache."
                    )
                )
                Divider().overlay(Color.white.opacity(0.12))
                sourceRow(
                    icon: "gamecontroller",
                    title: store.tr("Demos", "Demos"),
                    note: store.tr(
                        "Live aus dem Steam Store (Kategorie Demos) — kein Cache, immer aktuell.",
                        "Live from the Steam Store (Demos category) — no cache, always current."
                    )
                )
                Divider().overlay(Color.white.opacity(0.12))
                sourceRow(
                    icon: "archivebox.fill",
                    title: store.tr("Vault", "Vault"),
                    note: store.tr(
                        "Deine Einträge liegen nur lokal auf diesem iPhone (UserDefaults).",
                        "Your entries live only on this iPhone (UserDefaults)."
                    )
                )
            }
            .padding(18)
        }
    }

    private func sourceRow(icon: String, title: String, note: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(VaultAccent.teal)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
        }
    }

    // MARK: - About

    private var aboutCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(store.tr("ÜBER DIE APP", "ABOUT"))
                    .font(.caption2.weight(.bold)).tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))
                HStack {
                    Text(store.tr("App", "App"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Text("Playtest Vault")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                Divider().overlay(Color.white.opacity(0.12))
                HStack {
                    Text("Version")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Text("1.1.0")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .padding(18)
        }
    }
}
