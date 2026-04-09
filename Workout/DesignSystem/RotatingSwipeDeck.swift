import SwiftUI

struct RotatingSwipeDeckConfiguration {
    var visibleCount: Int = 3
    var dismissThresholdRatio: CGFloat = 0.28
    var maximumDismissThreshold: CGFloat = 140
    var maxRotation: Double = 18
    var stackSpacing: CGFloat = 14
    var dismissalTravel: CGFloat = 1.35
    var horizontalInset: CGFloat = 38
    var minimumCardWidth: CGFloat = 250
    var showsSideCues = true
    var sideCueColor: Color = AppTheme.accent
    var introHintEnabled = true
    var introHintVisibilityThreshold: CGFloat = 0.55
    var introHintOffset: CGFloat = 20
    var introHintRotation: Double = 6

    static let `default` = RotatingSwipeDeckConfiguration()
}

struct RotatingSwipeDeck<Item: Identifiable & Equatable, CardContent: View>: View {
    let items: [Item]
    var configuration: RotatingSwipeDeckConfiguration = .default
    let onAdvance: (Item) -> Void
    @ViewBuilder let cardContent: (Item) -> CardContent

    @State private var dragOffset: CGSize = .zero
    @State private var isAnimatingOut = false
    @State private var introOffset: CGFloat = .zero
    @State private var introRotation: Double = .zero
    @State private var hasPlayedIntroHint = false

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = deckCardWidth(in: proxy.size)

            ZStack {
                if configuration.showsSideCues {
                    sideCueLayer(in: proxy.size, cardWidth: cardWidth)
                }

                ZStack {
                    ForEach(Array(items.prefix(configuration.visibleCount).enumerated()), id: \.element.id) { index, item in
                        cardView(for: item, index: index, size: proxy.size, cardWidth: cardWidth)
                    }
                }
                .frame(width: cardWidth)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onScrollVisibilityChange(threshold: configuration.introHintVisibilityThreshold) { isVisible in
            guard isVisible else { return }
            triggerIntroHintIfNeeded()
        }
        .onChange(of: items.map(\.id)) {
            if !isAnimatingOut {
                dragOffset = .zero
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: dragOffset)
    }

    @ViewBuilder
    private func cardView(for item: Item, index: Int, size: CGSize, cardWidth: CGFloat) -> some View {
        let baseCard = cardContent(item)
            .scaleEffect(scale(for: index))
            .offset(y: stackYOffset(for: index))
            .offset(index == 0 ? CGSize(width: dragOffset.width + introOffset, height: dragOffset.height) : .zero)
            .rotationEffect(.degrees(index == 0 ? rotationAngle(for: cardWidth) + introRotation : 0))
            .zIndex(Double(configuration.visibleCount - index))
            .allowsHitTesting(index == 0 && !isAnimatingOut)

        if index == 0 && items.count > 1 {
            baseCard.highPriorityGesture(dragGesture(in: size, cardWidth: cardWidth))
        } else {
            baseCard
        }
    }

    private var dragProgress: CGFloat {
        min(abs(dragOffset.width) / 120, 1)
    }

    private func scale(for index: Int) -> CGFloat {
        let baseScale = max(1 - (CGFloat(index) * 0.04), 0.88)
        guard index > 0 else { return baseScale }
        return min(baseScale + (dragProgress * 0.04), 1 - (CGFloat(index - 1) * 0.04))
    }

    private func stackYOffset(for index: Int) -> CGFloat {
        let baseOffset = CGFloat(index) * configuration.stackSpacing
        guard index > 0 else { return 0 }
        return max(baseOffset - (dragProgress * configuration.stackSpacing), 0)
    }

    private func rotationAngle(for cardWidth: CGFloat) -> Double {
        let normalized = dragOffset.width / max(cardWidth, 1)
        return Double(normalized) * configuration.maxRotation
    }

    private func dismissThreshold(for cardWidth: CGFloat) -> CGFloat {
        min(max(cardWidth * configuration.dismissThresholdRatio, 96), configuration.maximumDismissThreshold)
    }

    private func dragGesture(in size: CGSize, cardWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isAnimatingOut else { return }
                cancelIntroHint()
                dragOffset = value.translation
            }
            .onEnded { value in
                guard !isAnimatingOut, let dismissedItem = items.first else { return }

                let projectedWidth = abs(value.predictedEndTranslation.width) > abs(value.translation.width)
                    ? value.predictedEndTranslation.width
                    : value.translation.width
                let shouldDismiss = abs(projectedWidth) > dismissThreshold(for: cardWidth)

                guard shouldDismiss else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                        dragOffset = .zero
                    }
                    return
                }

                let direction = projectedWidth == 0 ? (value.translation.width >= 0 ? 1.0 : -1.0) : projectedWidth.sign == .minus ? -1.0 : 1.0
                let targetWidth = max(size.width, 320) * configuration.dismissalTravel * direction
                let targetHeight = value.translation.height + (value.predictedEndTranslation.height * 0.15)

                isAnimatingOut = true
                Haptics.medium()

                withAnimation(.easeOut(duration: 0.22)) {
                    dragOffset = CGSize(width: targetWidth, height: targetHeight)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withTransaction(Transaction(animation: nil)) {
                        dragOffset = .zero
                        isAnimatingOut = false
                    }
                    onAdvance(dismissedItem)
                }
            }
    }

    private func deckCardWidth(in size: CGSize) -> CGFloat {
        let insetWidth = size.width - (configuration.horizontalInset * 2)
        let preferredWidth = max(insetWidth, configuration.minimumCardWidth)
        return min(preferredWidth, size.width)
    }

    @ViewBuilder
    private func sideCueLayer(in size: CGSize, cardWidth: CGFloat) -> some View {
        let cueWidth = max(((size.width - cardWidth) / 2) - 10, 18)

        HStack(spacing: 0) {
            SwipeDeckSideCue(direction: .left, color: configuration.sideCueColor)
                .frame(width: cueWidth, alignment: .trailing)
            Spacer(minLength: cardWidth)
            SwipeDeckSideCue(direction: .right, color: configuration.sideCueColor)
                .frame(width: cueWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func triggerIntroHintIfNeeded() {
        guard configuration.introHintEnabled,
              items.count > 1,
              !hasPlayedIntroHint,
              !isAnimatingOut,
              dragOffset == .zero else { return }

        hasPlayedIntroHint = true

        withAnimation(.easeInOut(duration: 0.24)) {
            introOffset = configuration.introHintOffset
            introRotation = configuration.introHintRotation
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                introOffset = .zero
                introRotation = .zero
            }
        }
    }

    private func cancelIntroHint() {
        guard introOffset != .zero || introRotation != .zero else { return }
        introOffset = .zero
        introRotation = .zero
    }
}

extension Array {
    func rotated(startingAt index: Int) -> [Element] {
        guard !isEmpty else { return [] }
        let normalizedIndex = ((index % count) + count) % count
        return Array(self[normalizedIndex...]) + self[..<normalizedIndex]
    }
}

private enum SwipeDeckCueDirection {
    case left
    case right

    var symbolName: String {
        switch self {
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        }
    }

    var multiplier: CGFloat {
        switch self {
        case .left: return -1
        case .right: return 1
        }
    }
}

private struct SwipeDeckSideCue: View {
    let direction: SwipeDeckCueDirection
    let color: Color

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: direction.symbolName)
                    .font(.caption.weight(.black))
                    .foregroundStyle(color.opacity(opacity(for: index)))
                    .offset(x: direction.multiplier * position(for: index))
            }
        }
        .frame(maxHeight: .infinity)
        .onAppear {
            guard !isAnimating else { return }
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private func opacity(for index: Int) -> CGFloat {
        let base = 0.2 + (CGFloat(index) * 0.14)
        return isAnimating ? min(base + 0.16, 0.72) : base
    }

    private func position(for index: Int) -> CGFloat {
        let baseSpacing: CGFloat = 8
        let animatedTravel: CGFloat = isAnimating ? 4 : 0
        return (CGFloat(index) * baseSpacing) + animatedTravel
    }
}
