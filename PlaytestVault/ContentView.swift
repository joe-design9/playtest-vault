import SwiftUI

@main
struct PlaytestVaultApp: App {
    @StateObject private var store: AppStore
    @StateObject private var feedStore: FeedStore
    @StateObject private var vaultStore: VaultStore

    init() {
        let appStore = AppStore()
        _store = StateObject(wrappedValue: appStore)
        _feedStore = StateObject(wrappedValue: FeedStore(uiTestMode: appStore.uiTestMode))
        _vaultStore = StateObject(wrappedValue: VaultStore(uiTestMode: appStore.uiTestMode))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(feedStore)
                .environmentObject(vaultStore)
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ZStack {
            TabView(selection: $store.selectedTab) {
                VaultPage { DiscoverView() }
                    .tabItem { Label(store.tr("Entdecken", "Discover"), systemImage: "safari") }
                    .tag(0)
                VaultPage { DemosView() }
                    .tabItem { Label(store.tr("Demos", "Demos"), systemImage: "gamecontroller") }
                    .tag(1)
                VaultPage { VaultView() }
                    .tabItem { Label(store.tr("Vault", "Vault"), systemImage: "archivebox.fill") }
                    .tag(2)
                VaultPage { MoreView() }
                    .tabItem { Label(store.tr("Mehr", "More"), systemImage: "ellipsis.circle.fill") }
                    .tag(3)
            }
            .tint(VaultAccent.teal)
            #if QA
            QABadge()
            #endif
        }
    }
}

#if QA
/// Red QA badge top-left — only visible in the QA build, never in Release.
private struct QABadge: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedStore: FeedStore
    @EnvironmentObject private var vaultStore: VaultStore

    var body: some View {
        VStack {
            HStack {
                Text("QA tab=\(store.selectedTab) feed=\(feedStore.items.count) vault=\(vaultStore.entries.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Spacer()
            }
            Spacer()
        }
        .padding(.top, 54)
        .padding(.leading, 10)
        .allowsHitTesting(false)
    }
}
#endif
