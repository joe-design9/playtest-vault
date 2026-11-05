import SwiftUI
import UIKit

/// Accent world for Playtest Vault: electric teal on pure black.
enum VaultAccent {
    static let teal = Color(red: 0.176, green: 0.831, blue: 0.749) // #2DD4BF
    static let deep = Color(red: 0.05, green: 0.45, blue: 0.42)

    static var gradient: LinearGradient {
        LinearGradient(colors: [teal, Color(red: 0.20, green: 0.60, blue: 0.95)], startPoint: .leading, endPoint: .trailing)
    }
}

/// Pure black backdrop with soft color fields (teal top, violet middle,
/// deep blue bottom), so the Liquid Glass surfaces have real color to
/// refract while the screens still read as black.
struct AppBackdrop: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [VaultAccent.teal.opacity(0.20), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color(red: 0.55, green: 0.25, blue: 0.85).opacity(0.10), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 460
            )
            RadialGradient(
                colors: [Color(red: 0.15, green: 0.35, blue: 0.85).opacity(0.13), .clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}

/// Wraps a tab page with the black backdrop INSIDE the page (a backdrop
/// behind the TabView gets covered by its container — Hub lesson).
struct VaultPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            AppBackdrop()
            content
        }
        .scrollContentBackground(.hidden)
    }
}

/// A Liquid Glass card, Hub recipe: clear fill, regular glass effect
/// with a light tint, and a hairline gradient border.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 26
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular.tint(.white.opacity(0.08)), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.30), Color.white.opacity(0.04)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }
}

extension View {
    /// Glass pill for small elements (badges, chips, input fields).
    func glassPill() -> some View {
        self
            .background {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular.tint(.white.opacity(0.08)), in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.30), Color.white.opacity(0.04)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }
}

/// Small capsule label with a colored glass tint (platform, status, Demo).
struct TintedPill: View {
    var text: String
    var color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular.tint(color.opacity(0.22)), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(color.opacity(0.35), lineWidth: 1)
                }
        }
    }
}

/// Countdown chip for deadlines — red under 48 hours, teal otherwise.
struct DeadlineChip: View {
    var deadline: Date

    var body: some View {
        let urgent = Countdown.isUrgent(deadline: deadline)
        let over = deadline.timeIntervalSinceNow <= 0
        TintedPill(
            text: Countdown.chipText(deadline: deadline),
            color: over ? .gray : (urgent ? .red : VaultAccent.teal),
            icon: "clock.fill"
        )
    }
}

/// Deterministic gradient placeholder art for items without an image:
/// a rich gradient plus the title initials, so every card looks designed.
struct CoverArt: View {
    var title: String
    var height: CGFloat = 150

    private static let palettes: [[Color]] = [
        [Color(red: 0.05, green: 0.55, blue: 0.50), Color(red: 0.10, green: 0.25, blue: 0.60)],
        [Color(red: 0.45, green: 0.20, blue: 0.75), Color(red: 0.85, green: 0.25, blue: 0.55)],
        [Color(red: 0.85, green: 0.40, blue: 0.15), Color(red: 0.65, green: 0.15, blue: 0.30)],
        [Color(red: 0.15, green: 0.50, blue: 0.30), Color(red: 0.05, green: 0.35, blue: 0.55)],
        [Color(red: 0.25, green: 0.30, blue: 0.80), Color(red: 0.10, green: 0.60, blue: 0.75)],
        [Color(red: 0.65, green: 0.30, blue: 0.10), Color(red: 0.35, green: 0.20, blue: 0.55)],
    ]

    private var palette: [Color] {
        var hash = 0
        for scalar in title.unicodeScalars { hash = hash &* 31 &+ Int(scalar.value) }
        return Self.palettes[abs(hash) % Self.palettes.count]
    }

    private var initials: String {
        let words = title.split(separator: " ").prefix(2)
        return words.compactMap { $0.first }.map { String($0) }.joined().uppercased()
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color.white.opacity(0.22), .clear], center: .topLeading, startRadius: 4, endRadius: 190)
            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: height * 0.34, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}

/// Cover image with graceful fallback: remote image when it loads,
/// gradient placeholder art otherwise (and while loading).
struct CoverImage: View {
    var url: URL?
    var title: String
    var height: CGFloat = 150

    var body: some View {
        ZStack {
            CoverArt(title: title, height: height)
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: height)
                            .clipped()
                    default:
                        Color.clear
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }
}

/// Short haptic tap for selections and actions.
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
