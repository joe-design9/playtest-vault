import SwiftUI
import UIKit

extension Color {
    /// Parses a "#RRGGBB" (or "RRGGBB") hex string; nil when malformed.
    init?(hexString: String) {
        var raw = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = UInt32(raw, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// Accent world for Playtest Vault: electric teal on pure black.
enum VaultAccent {
    static let teal = Color(red: 0.176, green: 0.831, blue: 0.749) // #2DD4BF
    static let deep = Color(red: 0.05, green: 0.45, blue: 0.42)

    static var gradient: LinearGradient {
        LinearGradient(colors: [teal, Color(red: 0.20, green: 0.60, blue: 0.95)], startPoint: .leading, endPoint: .trailing)
    }
}

/// Pure black backdrop with strong, layered color fields (teal top,
/// violet center, deep blue bottom, warm amber low-left, mint right),
/// so the Liquid Glass surfaces have real color to refract while the
/// screens still read as black.
struct AppBackdrop: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(
                colors: [VaultAccent.teal.opacity(0.40), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 430
            )
            RadialGradient(
                colors: [Color(red: 0.58, green: 0.25, blue: 0.90).opacity(0.27), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 470
            )
            RadialGradient(
                colors: [Color(red: 0.15, green: 0.38, blue: 0.90).opacity(0.29), .clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 400
            )
            RadialGradient(
                colors: [Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.15), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 340
            )
            RadialGradient(
                colors: [Color(red: 0.15, green: 0.85, blue: 0.55).opacity(0.15), .clear],
                center: .trailing,
                startRadius: 10,
                endRadius: 320
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
/// with a light tint, and a hairline gradient border. When an accent
/// is given, the glass tint, the border and a soft outer glow all pick
/// up that color, so every card carries its own game's identity.
struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 26
    var accent: Color? = nil
    @ViewBuilder var content: Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        content
            .background {
                shape
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(accent?.opacity(0.16) ?? .white.opacity(0.08)),
                        in: shape
                    )
                    .overlay {
                        shape
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        (accent ?? .white).opacity(accent == nil ? 0.30 : 0.55),
                                        Color.white.opacity(0.04),
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(color: accent?.opacity(0.22) ?? .clear, radius: 16, x: 0, y: 6)
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

/// Fallback art for items without a (loadable) image. With an accent
/// it renders as a designed brand tile: a rich duotone gradient in the
/// entry's own color, an oversized translucent game-controller glyph
/// and the title wordmark. Without an accent it falls back to the
/// deterministic title-hash palettes with initials.
struct CoverArt: View {
    var title: String
    var height: CGFloat = 150
    var accent: Color? = nil

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

    /// Short wordmark for the brand tile: title without any em-dash
    /// subtitle, capped so it fits the cover width.
    private var wordmark: String {
        let head = title.components(separatedBy: " \u{2014}").first ?? title
        return head.count > 22 ? String(head.prefix(22)) : head
    }

    var body: some View {
        ZStack {
            if let accent {
                LinearGradient(
                    colors: [accent.opacity(0.95), accent.opacity(0.45), Color.black.opacity(0.55)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RadialGradient(colors: [Color.white.opacity(0.28), .clear], center: .topLeading, startRadius: 4, endRadius: 200)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: height * 0.95))
                    .foregroundStyle(.white.opacity(0.13))
                    .offset(x: height * 0.42, y: height * 0.16)
                VStack(spacing: 4) {
                    Text(wordmark.uppercased())
                        .font(.system(size: height * 0.17, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 18)
                    Capsule()
                        .fill(.white.opacity(0.55))
                        .frame(width: 44, height: 3)
                }
            } else {
                LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color.white.opacity(0.22), .clear], center: .topLeading, startRadius: 4, endRadius: 190)
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: height * 0.34, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}

/// Shared in-memory cache so covers are not refetched while scrolling.
final class RemoteImageCache: @unchecked Sendable {
    static let shared = RemoteImageCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() { cache.countLimit = 150 }

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func store(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}

/// Robust remote image: downloads the bytes with URLSession and
/// decodes them with UIImage, IGNORING the server's Content-Type.
/// Some CDNs (Activision's, for one) serve perfectly valid image
/// bytes as application/octet-stream, which makes AsyncImage fail
/// silently. On any failure this renders nothing, so the caller's
/// designed fallback art underneath stays visible.
struct RemoteImage: View {
    var url: URL
    @State private var loaded: UIImage?

    var body: some View {
        Group {
            if let loaded {
                Image(uiImage: loaded)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.clear
            }
        }
        .task(id: url) {
            if let cached = RemoteImageCache.shared.image(for: url) {
                loaded = cached
                return
            }
            guard let data = try? await HTTP.get(url),
                  let decoded = UIImage(data: data) else { return }
            RemoteImageCache.shared.store(decoded, for: url)
            loaded = decoded
        }
    }
}

/// Cover image with graceful fallback: remote image when it loads,
/// designed fallback art otherwise (and while loading).
struct CoverImage: View {
    var url: URL?
    var title: String
    var height: CGFloat = 150
    var accent: Color? = nil

    var body: some View {
        ZStack {
            CoverArt(title: title, height: height, accent: accent)
            if let url {
                RemoteImage(url: url)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .clipped()
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
