import SwiftUI

struct TapCardDeckBadge: Equatable {
    /// 1-based index in the canonical deck ordering.
    var oneBasedPosition: Int
    var total: Int
}

struct TapCardPagerConfiguration {
    var tapSplitRatio: CGFloat = 0.5
    var wiggleDistance: CGFloat = 7
    var wiggleDuration: Double = 0.085
    var verticalAlignment: Alignment = .top
    var hapticsEnabled: Bool = true
    /// Corner radius matched to surrounding cards (SurfaceCard uses 24 pt).
    var cardCornerRadius: CGFloat = 24

    static let `default` = TapCardPagerConfiguration()
}

struct TapCardPager<Item: Identifiable & Equatable, CardContent: View>: View {
    let items: [Item]
    var configuration: TapCardPagerConfiguration = .default
    /// Shown in the top-trailing banner when total > 1.
    var deckBadge: TapCardDeckBadge? = nil
    let onAdvance: (Item) -> Void
    let onRetreat: (Item) -> Void
    @ViewBuilder let cardContent: (Item) -> CardContent

    @State private var wiggleOffset: CGFloat = 0
    @State private var wiggleGeneration = 0

    private let ringPeriodSeconds: Double = 2.2

    var body: some View {
        Group {
            if let item = items.first {
                let showInteractiveChrome = items.count > 1
                ZStack(alignment: .topTrailing) {
                    cardContent(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(x: wiggleOffset)
                        .overlay {
                            pulsingAccentRing(include: showInteractiveChrome)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                        .overlay {
                            GeometryReader { proxy in
                                let splitWidth = proxy.size.width * min(max(configuration.tapSplitRatio, 0.05), 0.95)
                                HStack(spacing: 0) {
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .frame(width: splitWidth)
                                        .onTapGesture { retreat(for: item) }

                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture { advance(for: item) }
                                }
                                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                            }
                            .allowsHitTesting(showInteractiveChrome)
                            .accessibilityHidden(true)
                        }
                        .padding(showInteractiveChrome ? 7 : 0)
                        .frame(maxWidth: .infinity, alignment: configuration.verticalAlignment)

                    if let badge = deckBadge, badge.total > 1 {
                        Text("\(badge.oneBasedPosition) of \(badge.total)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(AppTheme.accent.opacity(0.14))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(AppTheme.accent.opacity(0.42), lineWidth: 1)
                                    )
                            )
                            .shadow(color: AppTheme.accent.opacity(0.18), radius: 6, y: 2)
                            .padding(12)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAction {
                    advance(for: item)
                }
                .accessibilityAction(named: Text("Next")) {
                    advance(for: item)
                }
                .accessibilityAction(named: Text("Previous")) {
                    retreat(for: item)
                }
            } else {
                EmptyView()
            }
        }
        .onChange(of: items.map(\.id)) { _, _ in
            wiggleOffset = 0
            wiggleGeneration += 1
        }
    }

    @ViewBuilder
    private func pulsingAccentRing(include: Bool) -> some View {
        if include {
            TimelineView(.animation(minimumInterval: 1 / 36, paused: false)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let pulse = CGFloat((sin(t * (Double.pi * 2 / ringPeriodSeconds)) + 1) / 2)
                let innerLine = configuration.cardCornerRadius
                ZStack {
                    RoundedRectangle(cornerRadius: innerLine, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.05 + pulse * 0.18), lineWidth: 3)
                        .blur(radius: 5 + pulse * 5)

                    RoundedRectangle(cornerRadius: innerLine, style: .continuous)
                        .stroke(AppTheme.accent.opacity(0.1 + pulse * 0.22), lineWidth: 1.25)
                }
                .padding(-pulse * 2.5 - 1)
            }
        }
    }

    private func advance(for item: Item) {
        guard items.count > 1 else { return }
        if configuration.hapticsEnabled {
            Haptics.light()
        }
        onAdvance(item)
        playWiggle(.forward)
    }

    private func retreat(for item: Item) {
        guard items.count > 1 else { return }
        if configuration.hapticsEnabled {
            Haptics.light()
        }
        onRetreat(item)
        playWiggle(.backward)
    }

    private func playWiggle(_ direction: Direction) {
        let distance = direction == .forward ? configuration.wiggleDistance : -configuration.wiggleDistance
        wiggleGeneration += 1
        let generation = wiggleGeneration

        withAnimation(.easeOut(duration: configuration.wiggleDuration)) {
            wiggleOffset = distance
        }

        let reboundLead = configuration.wiggleDuration * 0.92
        DispatchQueue.main.asyncAfter(deadline: .now() + reboundLead) {
            guard generation == wiggleGeneration else { return }
            withAnimation(.spring(response: 0.1, dampingFraction: 0.82)) {
                wiggleOffset = 0
            }
        }
    }

    private enum Direction {
        case forward
        case backward
    }
}

extension Array {
    func rotated(startingAt index: Int) -> [Element] {
        guard !isEmpty else { return [] }
        let normalizedIndex = ((index % count) + count) % count
        return Array(self[normalizedIndex...]) + self[..<normalizedIndex]
    }
}
