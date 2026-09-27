import Charts
import SwiftUI

enum ExerciseProgressMetric: String, CaseIterable, Identifiable {
    case reps
    case weight
    case volume

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reps: return "Reps"
        case .weight: return "Weight"
        case .volume: return "Volume"
        }
    }

    func value(for set: SetEntry) -> Double {
        switch self {
        case .reps: return Double(set.reps)
        case .weight: return set.weight
        case .volume: return Double(set.reps) * set.weight
        }
    }

    func formattedValue(_ value: Double) -> String {
        switch self {
        case .reps:
            return "\(Int(value.rounded()))"
        case .weight, .volume:
            if value.rounded(.towardZero) == value {
                return "\(Int(value))"
            }
            return String(format: "%.1f", value)
        }
    }
}

struct ExerciseProgressGraphPoint: Identifiable, Hashable {
    let id: String
    let date: Date
    let value: Double
    let usedMachineOverload: Bool
    var valueUnit: String = ""
}

struct ExerciseProgressGraphSeries: Identifiable, Hashable {
    let setNumber: Int
    let points: [ExerciseProgressGraphPoint]

    var id: Int { setNumber }

    var label: String {
        "Set \(setNumber)"
    }
}

enum ExerciseProgressGraphDataBuilder {
    static func series(
        from snapshots: [HistorySnapshot],
        metric: ExerciseProgressMetric
    ) -> [ExerciseProgressGraphSeries] {
        let groupedPoints = pointsBySet(from: snapshots, metric: metric)
        return groupedPoints.keys.sorted().map { setNumber in
            ExerciseProgressGraphSeries(
                setNumber: setNumber,
                points: (groupedPoints[setNumber] ?? []).sorted { $0.date < $1.date }
            )
        }
    }

    static func repsSeries(from snapshots: [HistorySnapshot]) -> [ExerciseProgressGraphSeries] {
        series(from: snapshots, metric: .reps)
    }

    private static func pointsBySet(
        from snapshots: [HistorySnapshot],
        metric: ExerciseProgressMetric
    ) -> [Int: [ExerciseProgressGraphPoint]] {
        let pointsBySet = snapshots
            .flatMap { snapshot in
                snapshot.sets
                    .filter(\.completed)
                    .map { set in
                        (
                            set.setNumber,
                            ExerciseProgressGraphPoint(
                                id: "\(snapshot.sessionId.uuidString)-\(set.id.uuidString)",
                                date: snapshot.sessionDate,
                                value: metric.value(for: set),
                                usedMachineOverload: set.usedMachineOverload,
                                valueUnit: metric == .reps ? "reps" : (metric == .volume ? "\(set.weightUnit.displayName) × reps" : set.weightUnit.displayName)
                            )
                        )
                    }
            }
            .reduce(into: [Int: [ExerciseProgressGraphPoint]]()) { result, pair in
                result[pair.0, default: []].append(pair.1)
            }

        return pointsBySet
    }
}

struct ExerciseProgressGraph: View {
    let series: [ExerciseProgressGraphSeries]
    var metric: ExerciseProgressMetric = .reps
    var emptyMessage = "No graph history for this variation at this gym yet."
    var compact: Bool = true
    var minimumChartHeight: CGFloat? = nil
    var showsSummary: Bool = true

    @State private var selectedPointID: String?
    @State private var focusedSetNumber: Int?

    private var flattenedPoints: [ExerciseProgressGraphPoint] {
        series.flatMap(\.points)
    }

    private var displaySeries: [ExerciseProgressGraphSeries] {
        guard let focusedSetNumber else { return series }
        return series.sorted { first, second in
            if first.setNumber == focusedSetNumber { return false }
            if second.setNumber == focusedSetNumber { return true }
            return first.setNumber < second.setNumber
        }
    }

    private var chartMinimumHeight: CGFloat {
        minimumChartHeight ?? (compact ? 260 : 460)
    }

    private var maxValue: Double {
        max(flattenedPoints.map(\.value).max() ?? 0, 1)
    }

    var body: some View {
        if flattenedPoints.isEmpty {
            SurfaceCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No graph history")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: compact ? 220 : 360, alignment: .center)
            }
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Chart {
                    ForEach(displaySeries) { line in
                        ForEach(line.points) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value(metric.title, point.value),
                                series: .value("Set", line.label)
                            )
                            .foregroundStyle(by: .value("Set", line.label))
                            .interpolationMethod(.catmullRom)
                            .opacity(opacity(for: line))

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value(metric.title, point.value)
                            )
                            .symbol {
                                ExerciseProgressGraphPointSymbol(
                                    color: color(for: line),
                                    isHollow: point.usedMachineOverload
                                )
                            }
                            .opacity(opacity(for: line))
                            .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                                if selectedPointID == point.id {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(point.date, format: .dateTime.month(.abbreviated).day().year())
                                            .font(.caption)
                                        Text("\(line.label) · \(metric.title): \(metric.formattedValue(point.value)) \(point.valueUnit)")
                                            .font(.caption.weight(.semibold))
                                        if point.usedMachineOverload {
                                            Text("Machine overload").font(.caption)
                                        }
                                    }
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .padding(10)
                                    .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 12))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(color(for: line).opacity(0.6), lineWidth: 1)
                                    }
                                    .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                                    .allowsHitTesting(false)
                                }
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let plotFrame = proxy.plotFrame else { return }
                                let frame = geometry[plotFrame]
                                guard frame.contains(location) else {
                                    selectedPointID = nil
                                    return
                                }
                                let candidates = series
                                    .filter { focusedSetNumber == nil || $0.setNumber == focusedSetNumber }
                                    .flatMap(\.points)
                                let nearest = candidates.compactMap { point -> (String, CGFloat)? in
                                    guard let x = proxy.position(forX: point.date),
                                          let y = proxy.position(forY: point.value) else { return nil }
                                    let distance = hypot(location.x - frame.minX - x, location.y - frame.minY - y)
                                    return (point.id, distance)
                                }.min { $0.1 < $1.1 }
                                let tappedID = nearest.flatMap { $0.1 <= 32 ? $0.0 : nil }
                                selectedPointID = selectedPointID == tappedID ? nil : tappedID
                                if selectedPointID != nil { Haptics.light() }
                            }
                    }
                }
                .chartYAxisLabel(metric.title)
                .chartYScale(domain: 0...(maxValue + yAxisPadding))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: compact ? 4 : 7)) { value in
                        AxisGridLine()
                            .foregroundStyle(AppTheme.textMuted.opacity(0.18))
                        AxisTick()
                            .foregroundStyle(AppTheme.textMuted)
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                            .foregroundStyle(AppTheme.textMuted.opacity(0.18))
                        AxisTick()
                            .foregroundStyle(AppTheme.textMuted)
                        AxisValueLabel {
                            if let yValue = value.as(Double.self) {
                                Text(metric.formattedValue(yValue))
                            }
                        }
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .chartLegend(.hidden)
                .chartForegroundStyleScale(
                    domain: series.map(\.label),
                    range: series.map { color(for: $0) }
                )
                .frame(minHeight: chartMinimumHeight, maxHeight: compact ? nil : .infinity)

                ExerciseProgressGraphLegend(
                    series: series,
                    focusedSetNumber: focusedSetNumber,
                    color: color(for:),
                    onToggleFocus: toggleFocus
                )

                if showsSummary {
                    Text("\(flattenedPoints.count) logged set\(flattenedPoints.count == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
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
            .onChange(of: series.map(\.setNumber)) { _, setNumbers in
                if let focusedSetNumber, !setNumbers.contains(focusedSetNumber) {
                    self.focusedSetNumber = nil
                }
            }
            .onChange(of: series) { _, _ in selectedPointID = nil }
            .onChange(of: metric) { _, _ in selectedPointID = nil }
            .animation(.easeInOut(duration: 0.18), value: focusedSetNumber)
        }
    }

    private var yAxisPadding: Double {
        switch metric {
        case .reps: return 2
        case .weight, .volume: return max(5, maxValue * 0.08)
        }
    }

    private func toggleFocus(_ setNumber: Int) {
        selectedPointID = nil
        focusedSetNumber = focusedSetNumber == setNumber ? nil : setNumber
        Haptics.light()
    }

    private func opacity(for line: ExerciseProgressGraphSeries) -> Double {
        guard let focusedSetNumber else { return 1 }
        return line.setNumber == focusedSetNumber ? 1 : 0.18
    }

    private func color(for line: ExerciseProgressGraphSeries) -> Color {
        Self.seriesColor(for: line.setNumber)
    }

    private static func seriesColor(for setNumber: Int) -> Color {
        let palette: [Color] = [
            AppTheme.accent,
            AppTheme.accentSecondary,
            AppTheme.warning,
            AppTheme.danger,
            .purple,
            .mint,
            .pink,
            .indigo
        ]

        return palette[(max(setNumber, 1) - 1) % palette.count]
    }
}

private struct ExerciseProgressGraphPointSymbol: View {
    let color: Color
    let isHollow: Bool

    var body: some View {
        Circle()
            .fill(isHollow ? AppTheme.surface : color)
            .overlay {
                Circle()
                    .strokeBorder(color, lineWidth: isHollow ? 2 : 0)
            }
            .frame(width: 9, height: 9)
    }
}

private struct ExerciseProgressGraphLegend: View {
    let series: [ExerciseProgressGraphSeries]
    let focusedSetNumber: Int?
    let color: (ExerciseProgressGraphSeries) -> Color
    let onToggleFocus: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(series) { line in
                    ExerciseProgressGraphLegendButton(
                        line: line,
                        color: color(line),
                        isFocused: focusedSetNumber == line.setNumber,
                        isDimmed: focusedSetNumber != nil && focusedSetNumber != line.setNumber,
                        onTap: {
                            onToggleFocus(line.setNumber)
                        }
                    )
                }
            }
            .padding(.vertical, 1)
        }
        .accessibilityLabel("Graph legend")
    }
}

private struct ExerciseProgressGraphLegendButton: View {
    let line: ExerciseProgressGraphSeries
    let color: Color
    let isFocused: Bool
    let isDimmed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(line.label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isDimmed ? AppTheme.textMuted : AppTheme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isFocused ? color.opacity(0.14) : AppTheme.elevatedSurface.opacity(0.65))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isFocused ? color.opacity(0.9) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .opacity(isDimmed ? 0.58 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFocused ? "\(line.label), highlighted" : line.label)
        .accessibilityHint(isFocused ? "Tap to show all sets" : "Tap to highlight this set")
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }
}
