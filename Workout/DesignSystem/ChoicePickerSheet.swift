import SwiftUI

struct ChoicePickerOption: Identifiable, Equatable {
    let id: UUID
    var title: String
    var subtitle: String?
}

struct ChoicePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let options: [ChoicePickerOption]
    let currentID: UUID
    let bottomActionTitle: String?
    let bottomActionSystemImage: String?
    let onBottomAction: (() -> Void)?
    let onDone: (UUID) -> Void

    @State private var stagedID: UUID

    init(
        title: String,
        options: [ChoicePickerOption],
        currentID: UUID,
        bottomActionTitle: String? = nil,
        bottomActionSystemImage: String? = nil,
        onBottomAction: (() -> Void)? = nil,
        onDone: @escaping (UUID) -> Void
    ) {
        self.title = title
        self.options = options
        self.currentID = currentID
        self.bottomActionTitle = bottomActionTitle
        self.bottomActionSystemImage = bottomActionSystemImage
        self.onBottomAction = onBottomAction
        self.onDone = onDone
        _stagedID = State(initialValue: currentID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(options) { option in
                        Button {
                            stagedID = option.id
                            Haptics.light()
                        } label: {
                            ChoicePickerRow(
                                option: option,
                                isSelected: option.id == stagedID
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                if let bottomActionTitle, let onBottomAction {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onBottomAction()
                        }
                    } label: {
                        Label(bottomActionTitle, systemImage: bottomActionSystemImage ?? "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding()
                    .background(AppTheme.background)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(AppTheme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDone(stagedID)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            stagedID = currentID
        }
    }
}

private struct ChoicePickerRow: View {
    let option: ChoicePickerOption
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitle = option.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isSelected ? AppTheme.accent.opacity(0.55) : Color.white.opacity(0.06),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
    }
}

struct CompactChoiceTrigger: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(AppTheme.textMuted)

                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(AppTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
