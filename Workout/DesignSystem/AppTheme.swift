import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let surface = Color(red: 0.09, green: 0.09, blue: 0.12)
    static let elevatedSurface = Color(red: 0.13, green: 0.13, blue: 0.17)
    static let accent = Color(red: 0.18, green: 0.74, blue: 0.95)
    static let accentSecondary = Color(red: 0.49, green: 0.89, blue: 0.43)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textMuted = Color.white.opacity(0.45)
    static let danger = Color(red: 0.88, green: 0.34, blue: 0.38)
    static let warning = Color(red: 0.95, green: 0.69, blue: 0.24)
}

struct SurfaceCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.accent)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.elevatedSurface)
                    .opacity(configuration.isPressed ? 0.85 : 1)
            )
    }
}

struct DestructiveSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppTheme.danger)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.elevatedSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(configuration.isPressed ? 0.14 : 0))
                    )
                    .opacity(configuration.isPressed ? 0.88 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppTheme.danger.opacity(configuration.isPressed ? 0.72 : 0.58), lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
    }
}

struct StatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in: Capsule())
    }
}

struct SectionTitle: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

