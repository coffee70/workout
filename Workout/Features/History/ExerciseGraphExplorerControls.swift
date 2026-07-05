import SwiftUI

struct WorkoutExerciseGraphTabContent: View {
    let movementName: String
    let variationName: String
    let locationName: String
    let variationItems: [VariationDeckCardItem]
    let locationItems: [LocationHistorySelectorItem]
    let variationDeckBadge: TapCardDeckBadge?
    let locationDeckBadge: TapCardDeckBadge?
    @Binding var selectedMetric: ExerciseProgressMetric
    let graphSeries: [ExerciseProgressGraphSeries]
    var graphEmptyMessage = "No graph history for this variation at this gym yet."
    let onAdvanceVariation: () -> Void
    let onRetreatVariation: () -> Void
    let onAdvanceLocation: () -> Void
    let onRetreatLocation: () -> Void

    @State private var isFullscreenPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GraphExplorerControls(
                variationItems: variationItems,
                variationDeckBadge: variationDeckBadge,
                locationItems: locationItems,
                locationDeckBadge: locationDeckBadge,
                onAdvanceVariation: onAdvanceVariation,
                onRetreatVariation: onRetreatVariation,
                onAdvanceLocation: onAdvanceLocation,
                onRetreatLocation: onRetreatLocation
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text("\(selectedMetric.title) Over Time")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Button {
                        isFullscreenPresented = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 42, height: 42)
                            .background(
                                Circle()
                                    .fill(AppTheme.accent.opacity(0.16))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open Fullscreen Graph")
                }

                GraphMetricPicker(selectedMetric: $selectedMetric)

                ExerciseProgressGraph(
                    series: graphSeries,
                    metric: selectedMetric,
                    emptyMessage: graphEmptyMessage,
                    compact: true
                )
            }
        }
        .fullScreenCover(isPresented: $isFullscreenPresented) {
            LandscapeExerciseGraphFullScreen(
                movementName: movementName,
                variationName: variationName,
                locationName: locationName,
                selectedMetric: $selectedMetric,
                graphSeries: graphSeries,
                onClose: {
                    isFullscreenPresented = false
                }
            )
        }
    }
}

struct GraphMetricPicker: View {
    @Binding var selectedMetric: ExerciseProgressMetric

    var body: some View {
        Picker("Graph Metric", selection: $selectedMetric) {
            ForEach(ExerciseProgressMetric.allCases) { metric in
                Text(metric.title).tag(metric)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Graph Metric")
    }
}

struct LandscapeExerciseGraphFullScreen: View {
    let movementName: String
    let variationName: String
    let locationName: String
    @Binding var selectedMetric: ExerciseProgressMetric
    let graphSeries: [ExerciseProgressGraphSeries]
    let onClose: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let shouldRotate = size.height > size.width
            let landscapeSize = CGSize(
                width: shouldRotate ? size.height : size.width,
                height: shouldRotate ? size.width : size.height
            )

            LandscapeExerciseGraphContent(
                movementName: movementName,
                variationName: variationName,
                locationName: locationName,
                selectedMetric: $selectedMetric,
                graphSeries: graphSeries,
                onClose: onClose
            )
            .frame(width: landscapeSize.width, height: landscapeSize.height)
            .rotationEffect(shouldRotate ? .degrees(90) : .zero)
            .position(x: size.width / 2, y: size.height / 2)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .statusBarHidden(true)
    }
}

private struct LandscapeExerciseGraphContent: View {
    let movementName: String
    let variationName: String
    let locationName: String
    @Binding var selectedMetric: ExerciseProgressMetric
    let graphSeries: [ExerciseProgressGraphSeries]
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            ExerciseProgressGraph(
                series: graphSeries,
                metric: selectedMetric,
                compact: false,
                minimumChartHeight: 180,
                showsSummary: false
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 64)

            LandscapeGraphToolbar(
                movementName: movementName,
                variationName: variationName,
                locationName: locationName,
                selectedMetric: $selectedMetric,
                onClose: onClose
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppTheme.background)
    }
}

private struct LandscapeGraphToolbar: View {
    let movementName: String
    let variationName: String
    let locationName: String
    @Binding var selectedMetric: ExerciseProgressMetric
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(locationName.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
                Text("\(movementName) - \(variationName)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 8)

            GraphMetricPicker(selectedMetric: $selectedMetric)
                .frame(width: 190)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(AppTheme.elevatedSurface)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Return to Normal Graph")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct GraphExplorerControls: View {
    let variationItems: [VariationDeckCardItem]
    let variationDeckBadge: TapCardDeckBadge?
    let locationItems: [LocationHistorySelectorItem]
    let locationDeckBadge: TapCardDeckBadge?
    let onAdvanceVariation: () -> Void
    let onRetreatVariation: () -> Void
    let onAdvanceLocation: () -> Void
    let onRetreatLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Graph Filters")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)

            VStack(alignment: .leading, spacing: 12) {
                variationSelector
                    .frame(maxWidth: .infinity, alignment: .leading)
                locationSelector
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var variationSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Variation")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textMuted)

            if variationItems.isEmpty {
                compactEmptyCard(message: "No variations")
            } else {
                TapCardPager(
                    items: variationItems,
                    deckBadge: variationDeckBadge,
                    onAdvance: { _ in onAdvanceVariation() },
                    onRetreat: { _ in onRetreatVariation() }
                ) { item in
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.variation.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let equipmentCategory = item.variation.equipmentCategory {
                                Text(equipmentCategory.displayName)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    }
                }
                .frame(minHeight: 118)
            }
        }
    }

    private var locationSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gym")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.textMuted)

            if locationItems.isEmpty {
                compactEmptyCard(message: "No gyms")
            } else {
                TapCardPager(
                    items: locationItems,
                    deckBadge: locationDeckBadge,
                    onAdvance: { _ in onAdvanceLocation() },
                    onRetreat: { _ in onRetreatLocation() }
                ) { item in
                    SurfaceCard {
                        Text(item.location.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    }
                }
                .frame(minHeight: 118)
            }
        }
    }

    private func compactEmptyCard(message: String) -> some View {
        SurfaceCard {
            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
        }
    }
}

struct VariationDeckCardItem: Identifiable, Equatable {
    let variation: Variation

    var id: UUID { variation.id }
}

struct LocationHistorySelectorItem: Identifiable, Equatable {
    let location: Location

    var id: UUID { location.id }
}

func orderedIDs(
    currentIDs: [UUID],
    preferredOrder: [UUID],
    fallbackCurrentID: UUID
) -> [UUID] {
    guard !currentIDs.isEmpty else { return [] }

    let currentIDSet = Set(currentIDs)
    let filteredPreferred = preferredOrder.filter { currentIDSet.contains($0) }
    let missingIDs = currentIDs.filter { !filteredPreferred.contains($0) }
    let merged = filteredPreferred + missingIDs

    if let currentIndex = merged.firstIndex(of: fallbackCurrentID) {
        return merged.rotated(startingAt: currentIndex)
    }

    return merged
}
