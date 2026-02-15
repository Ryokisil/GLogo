//
//  AdjustBasicPanelView.swift
//  GLogo
//
//  概要:
//  下部ツールストリップの「Adjust」から表示される基礎色調整パネルです。
//  彩度・明度・ブラー・コントラスト・シャドウ・ハイライト・黒/白レベル・色温度・ヴィブランス・色相・シャープネス・カーブを
//  カテゴリ別（Color / Light / Detail）の選択UIとスライダーで編集します。
//

import SwiftUI

private enum AdjustBasicControl: CaseIterable, Identifiable {
    // Color
    case saturation
    case vibrance
    case temperature
    case hue

    // Light
    case brightness
    case contrast
    case highlights
    case shadows
    case blacks
    case whites

    // Detail
    case sharpness
    case blur
    case curve

    var id: String { title }

    var title: String {
        switch self {
        case .saturation:
            return "Saturation"
        case .brightness:
            return "Brightness"
        case .blur:
            return "Blur"
        case .contrast:
            return "Contrast"
        case .shadows:
            return "Shadows"
        case .highlights:
            return "Highlights"
        case .blacks:
            return "Blacks"
        case .whites:
            return "Whites"
        case .temperature:
            return "Temperature"
        case .vibrance:
            return "Vibrance"
        case .hue:
            return "Hue"
        case .sharpness:
            return "Sharpness"
        case .curve:
            return "Curve"
        }
    }

    /// SF Symbol アイコン名
    var systemImageName: String {
        switch self {
        case .saturation:  return "drop.fill"
        case .brightness:  return "sun.max.fill"
        case .blur:        return "aqi.medium"
        case .contrast:    return "circle.lefthalf.filled"
        case .shadows:     return "moon.fill"
        case .highlights:  return "sun.min.fill"
        case .blacks:      return "circle.bottomhalf.filled"
        case .whites:      return "circle.tophalf.filled"
        case .temperature: return "thermometer.medium"
        case .vibrance:    return "sparkles"
        case .hue:         return "paintpalette.fill"
        case .sharpness:   return "scope"
        case .curve:       return "chart.xyaxis.line"
        }
    }

    var key: ImageAdjustmentKey? {
        switch self {
        case .saturation:
            return .saturation
        case .brightness:
            return .brightness
        case .blur:
            return .gaussianBlur
        case .contrast:
            return .contrast
        case .shadows:
            return .shadows
        case .highlights:
            return .highlights
        case .blacks:
            return .blacks
        case .whites:
            return .whites
        case .temperature:
            return .temperature
        case .vibrance:
            return .vibrance
        case .hue:
            return .hue
        case .sharpness:
            return .sharpness
        case .curve:
            return nil
        }
    }

    var range: ClosedRange<CGFloat> {
        switch self {
        case .saturation:
            return 0...2
        case .brightness:
            return -0.5...0.5
        case .blur:
            return 0...10
        case .contrast:
            return 0.5...1.5
        case .shadows:
            return -1...1
        case .highlights:
            return -1...1
        case .blacks:
            return -1...1
        case .whites:
            return -1...1
        case .temperature:
            return -100...100
        case .vibrance:
            return -1...1
        case .hue:
            return -180...180
        case .sharpness:
            return 0...2
        case .curve:
            return 0...1
        }
    }

    var step: CGFloat {
        switch self {
        case .blur:
            return 0.1
        case .hue:
            return 1
        case .temperature:
            return 1
        case .curve:
            return 0.01
        default:
            return 0.01
        }
    }

    var defaultValue: CGFloat {
        switch self {
        case .saturation:
            return 1
        case .brightness:
            return 0
        case .blur:
            return 0
        case .contrast:
            return 1
        case .shadows:
            return 0
        case .highlights:
            return 0
        case .blacks:
            return 0
        case .whites:
            return 0
        case .temperature:
            return 0
        case .vibrance:
            return 0
        case .hue:
            return 0
        case .sharpness:
            return 0
        case .curve:
            return 0
        }
    }
}

private enum AdjustControlCategory: CaseIterable, Identifiable {
    case color
    case light
    case detail

    var id: String { title }

    var title: String {
        switch self {
        case .color:
            return "Color"
        case .light:
            return "Light"
        case .detail:
            return "Detail"
        }
    }

    var controls: [AdjustBasicControl] {
        switch self {
        case .color:
            return [.saturation, .vibrance, .temperature, .hue]
        case .light:
            return [.brightness, .contrast, .highlights, .shadows, .blacks, .whites]
        case .detail:
            return [.sharpness, .blur, .curve]
        }
    }
}

struct AdjustBasicPanelView: View {
    @ObservedObject var viewModel: ElementViewModel
    let onClose: () -> Void

    @State private var selectedControl: AdjustBasicControl = .contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if viewModel.imageElement != nil {
                controlSelector
                editorSection
            } else {
                Text("Select an image to adjust.")
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
                resetSelectedAdjustment()
            }
            .font(.subheadline.weight(.semibold))
            .disabled(!canResetSelectedAdjustment())

            Spacer()

            Text("Adjust")
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
                ForEach(AdjustControlCategory.allCases) { category in
                    categoryCard(category)
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
    }

    private func categoryCard(_ category: AdjustControlCategory) -> some View {
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

    private var editorSection: some View {
        Group {
            if selectedControl == .curve {
                toneCurveSection
            } else {
                sliderSection
            }
        }
    }

    private func controlCard(_ control: AdjustBasicControl) -> some View {
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

                    // デフォルト値から変更済みの場合にドットを表示
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
            .frame(width: 62, height: 48)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.10))
            )
            .shadow(
                color: isSelected ? Color.blue.opacity(0.25) : .clear,
                radius: 4, y: 2
            )
            .scaleEffect(isSelected ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var sliderSection: some View {
        let valueBinding = Binding(
            get: { valueForSelectedControl() },
            set: { newValue in
                guard let key = selectedControl.key else { return }
                viewModel.updateImageAdjustment(key, value: newValue)
            }
        )
        let isEdited = canResetSelectedAdjustment()

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
                        guard let key = selectedControl.key else { return }
                        if isEditing {
                            viewModel.beginImageAdjustmentEditing(key)
                        } else {
                            viewModel.commitImageAdjustmentEditing(key)
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

    private var toneCurveSection: some View {
        let curveBinding = Binding<ToneCurveData>(
            get: { viewModel.imageElement?.toneCurveData ?? ToneCurveData() },
            set: { newData in
                viewModel.updateToneCurveData(newData)
            }
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: selectedControl.systemImageName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)

                Text(selectedControl.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }

            ToneCurveView(curveData: curveBinding, layout: .compact)
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.gray.opacity(0.08))
                )
        }
    }

    private func valueForSelectedControl() -> CGFloat {
        guard let imageElement = viewModel.imageElement,
              let key = selectedControl.key,
              let descriptor = ImageAdjustmentDescriptor.all[key] else {
            return selectedControl.defaultValue
        }
        return imageElement[keyPath: descriptor.keyPath]
    }

    private func valueText() -> String {
        let value = valueForSelectedControl()
        if selectedControl == .hue || selectedControl == .temperature {
            return "\(Int(value))"
        }
        return String(format: "%.2f", value)
    }

    private func resetSelectedAdjustment() {
        guard canResetSelectedAdjustment() else { return }
        if selectedControl == .curve {
            viewModel.updateToneCurveData(ToneCurveData())
            return
        }
        guard let key = selectedControl.key else { return }
        viewModel.beginImageAdjustmentEditing(key)
        viewModel.updateImageAdjustment(key, value: selectedControl.defaultValue)
        viewModel.commitImageAdjustmentEditing(key)
    }

    private func canResetSelectedAdjustment() -> Bool {
        isControlEdited(selectedControl)
    }

    private func valueFor(_ control: AdjustBasicControl) -> CGFloat {
        guard let imageElement = viewModel.imageElement,
              let key = control.key,
              let descriptor = ImageAdjustmentDescriptor.all[key] else {
            return control.defaultValue
        }
        return imageElement[keyPath: descriptor.keyPath]
    }

    private func isControlEdited(_ control: AdjustBasicControl) -> Bool {
        guard let imageElement = viewModel.imageElement else { return false }
        if control == .curve {
            return imageElement.toneCurveData != ToneCurveData()
        }
        return abs(valueFor(control) - control.defaultValue) > 0.0001
    }
}
