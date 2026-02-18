//
//  EffectsPanelView.swift
//  GLogo
//
//  FXタブ（ビネット/ブルーム/グレイン/フェード/色収差）の調整UIを提供するビュー。
//

import SwiftUI

private enum EffectsControl: CaseIterable, Identifiable {
    case vignette
    case bloom
    case grain
    case fade
    case chromaticAberration

    var id: String { title }

    var title: String {
        switch self {
        case .vignette:
            return "Vignette"
        case .bloom:
            return "Bloom"
        case .grain:
            return "Grain"
        case .fade:
            return "Fade"
        case .chromaticAberration:
            return "Aberration"
        }
    }

    var systemImageName: String {
        switch self {
        case .vignette:
            return "circle.dashed.inset.filled"
        case .bloom:
            return "sparkles"
        case .grain:
            return "square.grid.3x3.fill"
        case .fade:
            return "camera.aperture"
        case .chromaticAberration:
            return "camera.macro"
        }
    }

    var key: ImageAdjustmentKey {
        switch self {
        case .vignette:
            return .vignette
        case .bloom:
            return .bloom
        case .grain:
            return .grain
        case .fade:
            return .fade
        case .chromaticAberration:
            return .chromaticAberration
        }
    }

    var range: ClosedRange<CGFloat> {
        0...1
    }

    var step: CGFloat {
        0.01
    }

    var defaultValue: CGFloat {
        0
    }
}

private enum EffectsCategory: CaseIterable, Identifiable {
    case light
    case film
    case lens

    var id: String { title }

    var title: String {
        switch self {
        case .light:
            return "Light"
        case .film:
            return "Film"
        case .lens:
            return "Lens"
        }
    }

    var controls: [EffectsControl] {
        switch self {
        case .light:
            return [.vignette, .bloom]
        case .film:
            return [.grain, .fade]
        case .lens:
            return [.chromaticAberration]
        }
    }
}

struct EffectsPanelView: View {
    @ObservedObject var viewModel: ElementViewModel
    let onClose: () -> Void

    @State private var selectedControl: EffectsControl = .vignette

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if viewModel.imageElement != nil {
                controlSelector
                sliderSection
            } else {
                Text("Select an image to edit FX.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Button("Reset") {
                resetSelectedEffect()
            }
            .font(.subheadline.weight(.semibold))
            .disabled(!canResetSelectedEffect())

            Spacer()

            Text("FX")
                .font(.headline)

            Spacer()

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var controlSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(EffectsCategory.allCases) { category in
                    categoryCard(category)
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
    }

    private func categoryCard(_ category: EffectsCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                ForEach(category.controls) { control in
                    controlCard(control)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
    }

    private func controlCard(_ control: EffectsControl) -> some View {
        let isSelected = control == selectedControl
        let isEdited = isControlEdited(control)

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedControl = control
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: control.systemImageName)
                        .font(.system(size: 16, weight: .medium))
                        .frame(width: 20, height: 20)

                    if isEdited {
                        Circle()
                            .fill(isSelected ? Color.white : Color.blue)
                            .frame(width: 5, height: 5)
                            .offset(x: 3, y: -2)
                    }
                }

                Text(control.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .frame(width: 72, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.10))
            )
            .shadow(
                color: isSelected ? Color.blue.opacity(0.25) : .clear,
                radius: 4,
                y: 2
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var sliderSection: some View {
        let valueBinding = Binding(
            get: { valueForSelectedControl() },
            set: { newValue in
                viewModel.updateImageAdjustment(selectedControl.key, value: newValue)
            }
        )
        let isEdited = canResetSelectedEffect()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: selectedControl.systemImageName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)

                Text(selectedControl.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            HStack(spacing: 12) {
                Slider(
                    value: valueBinding,
                    in: selectedControl.range,
                    step: selectedControl.step,
                    onEditingChanged: { isEditing in
                        if isEditing {
                            viewModel.beginImageAdjustmentEditing(selectedControl.key)
                        } else {
                            viewModel.commitImageAdjustmentEditing(selectedControl.key)
                        }
                    }
                )
                .tint(.blue)

                Text(valueText())
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundColor(isEdited ? .blue : .secondary)
                    .frame(width: 52, alignment: .trailing)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isEdited ? Color.blue.opacity(0.10) : Color.gray.opacity(0.10))
                    )
            }
        }
    }

    private func valueForSelectedControl() -> CGFloat {
        valueFor(selectedControl)
    }

    private func valueFor(_ control: EffectsControl) -> CGFloat {
        guard let imageElement = viewModel.imageElement,
              let descriptor = ImageAdjustmentDescriptor.all[control.key] else {
            return control.defaultValue
        }
        return imageElement[keyPath: descriptor.keyPath]
    }

    private func valueText() -> String {
        String(format: "%.2f", valueForSelectedControl())
    }

    private func resetSelectedEffect() {
        guard canResetSelectedEffect() else { return }
        viewModel.beginImageAdjustmentEditing(selectedControl.key)
        viewModel.updateImageAdjustment(selectedControl.key, value: selectedControl.defaultValue)
        viewModel.commitImageAdjustmentEditing(selectedControl.key)
    }

    private func canResetSelectedEffect() -> Bool {
        isControlEdited(selectedControl)
    }

    private func isControlEdited(_ control: EffectsControl) -> Bool {
        abs(valueFor(control) - control.defaultValue) > 0.0001
    }
}
