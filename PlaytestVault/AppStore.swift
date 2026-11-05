import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedTab = 0
    @Published var language: String = Lang.code

    /// QA screenshot mode (-UITestMode launch argument): seeds the vault
    /// with demo entries and swaps every network source for bundled
    /// sample data. The argument works in any build configuration.
    let uiTestMode: Bool

    init() {
        let args = ProcessInfo.processInfo.arguments
        uiTestMode = args.contains("-UITestMode")
        // QA hook: preselect a tab for simulator screenshots.
        if let idx = args.firstIndex(of: "-QAStartTab"), idx + 1 < args.count,
           let tab = Int(args[idx + 1]), (0...3).contains(tab) {
            selectedTab = tab
        }
    }

    /// Short language helper for all views: tr("Deutsch", "English").
    func tr(_ de: String, _ en: String) -> String { language.hasPrefix("de") ? de : en }

    func setLanguage(_ newValue: String) {
        guard newValue != language else { return }
        language = newValue
        UserDefaults.standard.set(newValue, forKey: "appLanguage")
    }
}
