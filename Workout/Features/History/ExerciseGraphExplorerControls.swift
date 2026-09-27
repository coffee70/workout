import SwiftUI

struct WorkoutExerciseGraphTabContent: View {
    let movementName: String
    let variationName: String
    let locationName: String
    let variationItems: [VariationDeckCardItem]
    let locationItems: [LocationHistorySelectorItem]
    let selectedVariationId: UUID
    let selectedLocationId: UUID
    @Binding var selectedMetric: ExerciseProgressMetric
    let graphSeries: [ExerciseProgressGraphSeries]
    var graphEmptyMessage = "No graph history for this variation at this gym yet."
    let onSelectVariation: (UUID) -> Void
    let onSelectLocation: (UUID) -> Void

    @State private var isFullscreenPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GraphExplorerControls(
                variationItems: variationItems,
                locationItems: locationItems,
                selectedVariationId: selectedVariationId,
                selectedLocationId: selectedLocationId,
                onSelectVariation: onSelectVariation,
                onSelectLocation: onSelectLocation
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text("\(selectedMetric.title) Over Time")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Button {
                        openFullscreenGraph()
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
                .onTapGesture(count: 2) {
                    openFullscreenGraph()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func openFullscreenGraph() {
        isFullscreenPresented = true
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
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.surface.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}

struct GraphExplorerControls: View {
    let variationItems: [VariationDeckCardItem]
    let locationItems: [LocationHistorySelectorItem]
    let selectedVariationId: UUID
    let selectedLocationId: UUID
    let onSelectVariation: (UUID) -> Void
    let onSelectLocation: (UUID) -> Void

    @State private var isVariationPickerPresented = false
    @State private var isLocationPickerPresented = false

    private var selectedVariation: VariationDeckCardItem? {
        variationItems.first { $0.id == selectedVariationId } ?? variationItems.first
    }

    private var selectedLocation: LocationHistorySelectorItem? {
        locationItems.first { $0.id == selectedLocationId } ?? locationItems.first
    }

    private var variationOptions: [ChoicePickerOption] {
        variationItems.map { item in
            ChoicePickerOption(
                id: item.variation.id,
                title: item.variation.name,
                subtitle: item.variation.equipmentCategory?.displayName
            )
        }
    }

    private var locationOptions: [ChoicePickerOption] {
        locationItems.map { item in
            ChoicePickerOption(
                id: item.location.id,
                title: item.location.name,
                subtitle: item.location.notes
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Graph Filters")
                .font(.headline)
                .foregroundStyle(AppTheme.textSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    variationTrigger
                    locationTrigger
                }

                VStack(alignment: .leading, spacing: 12) {
                    variationTrigger
                    locationTrigger
                }
            }
        }
        .fullScreenCover(isPresented: $isVariationPickerPresented) {
            ChoicePickerSheet(
                title: "Choose Variation",
                options: variationOptions,
                currentID: selectedVariationId,
                onDone: onSelectVariation
            )
        }
        .fullScreenCover(isPresented: $isLocationPickerPresented) {
            ChoicePickerSheet(
                title: "Choose Gym",
                options: locationOptions,
                currentID: selectedLocationId,
                onDone: onSelectLocation
            )
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

    @ViewBuilder
    private var variationTrigger: some View {
        if variationItems.isEmpty {
            compactEmptyCard(message: "No variations")
        } else {
            CompactChoiceTrigger(
                title: "Variation",
                value: selectedVariation?.variation.name ?? "Choose",
                subtitle: selectedVariation?.variation.equipmentCategory?.displayName
            ) {
                isVariationPickerPresented = true
            }
        }
    }

    @ViewBuilder
    private var locationTrigger: some View {
        if locationItems.isEmpty {
            compactEmptyCard(message: "No gyms")
        } else {
            CompactChoiceTrigger(
                title: "Gym",
                value: selectedLocation?.location.name ?? "Choose",
                subtitle: nil
            ) {
                isLocationPickerPresented = true
            }
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
