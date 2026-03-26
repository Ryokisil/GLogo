//
//  FramePanelView.swift
//  GLogo
//
//  概要:
//  下部ツールストリップの「Frame」から表示されるフレームプリセット編集パネルです。
//  選択中画像に対してフレームの追加、スタイル切り替え、色・太さ・角丸の調整を提供します。
//

import SwiftUI
import UIKit

private enum FrameStyleCategory: String, CaseIterable, Identifiable {
    case classic
    case print
    case expressive

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .classic:
            return "frame.category.classic"
        case .print:
            return "frame.category.print"
        case .expressive:
            return "frame.category.expressive"
        }
    }

    var styles: [ImageFrameStyle] {
        switch self {
        case .classic:
            return [.simple, .double, .cornerAccent]
        case .print:
            return [.polaroid, .film, .stamp]
        case .expressive:
            return [.neon, .badge]
        }
    }
}

private extension ImageFrameStyle {
    var titleKey: LocalizedStringKey {
        switch self {
        case .simple:
            return "frame.style.simple"
        case .double:
            return "frame.style.double"
        case .cornerAccent:
            return "frame.style.cornerAccent"
        case .polaroid:
            return "frame.style.polaroid"
        case .film:
            return "frame.style.film"
        case .neon:
            return "frame.style.neon"
        case .badge:
            return "frame.style.badge"
        case .stamp:
            return "frame.style.stamp"
        case .softWhite, .glassWhite, .editorialWhite:
            return "frame.style.softOverlay"
        }
    }
}

struct FramePanelView: View {
    @ObservedObject var viewModel: ElementViewModel
    let onClose: () -> Void
    private let maxPanelHeight: CGFloat = 240

    private let presetColors: [UIColor] = [
        .white,
        UIColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1),
        UIColor(red: 0.96, green: 0.77, blue: 0.18, alpha: 1),
        UIColor(red: 0.24, green: 0.58, blue: 0.98, alpha: 1),
        UIColor(red: 0.10, green: 0.82, blue: 0.69, alpha: 1),
        UIColor(red: 0.96, green: 0.38, blue: 0.62, alpha: 1),
        UIColor(red: 0.57, green: 0.34, blue: 0.95, alpha: 1),
        UIColor(red: 0.90, green: 0.42, blue: 0.20, alpha: 1)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    if let imageElement = viewModel.imageElement {
                        styleSelector(imageElement)
                        frameControlSection(imageElement)
                        roundnessSection(imageElement)
                    } else {
                        Text("frame.selectImage")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.trailing, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: maxPanelHeight, alignment: .top)
        .padding(12)
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
            Button("frame.remove") {
                viewModel.updateShowFrame(false)
            }
            .font(.subheadline.weight(.semibold))
            .disabled(viewModel.imageElement?.showFrame != true)

            Spacer()

            Text("frame.title")
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

    private func styleSelector(_ imageElement: ImageElement) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(FrameStyleCategory.allCases) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.title)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            ForEach(category.styles, id: \.self) { style in
                                styleCard(style, imageElement: imageElement)
                            }
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.gray.opacity(0.08))
                    )
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
    }

    private func styleCard(_ style: ImageFrameStyle, imageElement: ImageElement) -> some View {
        let isSelected = imageElement.showFrame && isMatchingStyle(style, selectedStyle: imageElement.frameStyle)
        let previewColor = Color(imageElement.frameColor)

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                viewModel.updateFrameStyle(style)
            }
        } label: {
            VStack(spacing: 6) {
                FrameStylePreview(style: style, color: previewColor, isSelected: isSelected)
                    .frame(width: 66, height: 52)

                Text(style.titleKey)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 70)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.blue : Color.black.opacity(0.06), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func frameControlSection(_ imageElement: ImageElement) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("frame.width")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(imageElement.frameWidth, specifier: "%.1f")")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Slider(
                value: Binding(
                    get: { imageElement.frameWidth },
                    set: { viewModel.updateImageAdjustment(.frameWidth, value: $0) }
                ),
                in: 2...28,
                step: 0.5,
                onEditingChanged: { isEditing in
                    if isEditing {
                        viewModel.beginImageAdjustmentEditing(.frameWidth)
                    } else {
                        viewModel.commitImageAdjustmentEditing(.frameWidth)
                    }
                }
            )
            .disabled(!imageElement.showFrame)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("frame.color")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    ColorPicker(
                        "",
                        selection: Binding(
                            get: { Color(imageElement.frameColor) },
                            set: { newColor in
                                let updatedColor = UIColor(newColor).withAlphaComponent(imageElement.frameColor.cgColor.alpha)
                                viewModel.updateFrameColor(updatedColor)
                            }
                        ),
                        supportsOpacity: false
                    )
                    .labelsHidden()
                }

                HStack {
                    Text("frame.opacity")
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text("\(Int((imageElement.frameColor.cgColor.alpha * 100).rounded()))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { imageElement.frameColor.cgColor.alpha },
                        set: { viewModel.previewFrameColor(imageElement.frameColor.withAlphaComponent($0)) }
                    ),
                    in: 0.08...1.0,
                    step: 0.01,
                    onEditingChanged: { isEditing in
                        if isEditing {
                            viewModel.beginFrameColorEditing()
                        } else {
                            viewModel.commitFrameColorEditing()
                        }
                    }
                )
                .disabled(!imageElement.showFrame)

                HStack(spacing: 10) {
                    ForEach(Array(presetColors.enumerated()), id: \.offset) { entry in
                        let color = entry.element.withAlphaComponent(imageElement.frameColor.cgColor.alpha)
                        let isSelected = imageElement.frameColor.isEqual(color)
                        Button {
                            viewModel.updateFrameColor(color)
                        } label: {
                            Circle()
                                .fill(Color(color))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.82), lineWidth: 1)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(isSelected ? Color.blue : Color.black.opacity(0.10), lineWidth: isSelected ? 3 : 1)
                                        .padding(isSelected ? -3 : 0)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!imageElement.showFrame)
                    }
                }
            }
        }
        .opacity(imageElement.showFrame ? 1 : 0.55)
    }

    private func roundnessSection(_ imageElement: ImageElement) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("frame.rounded")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { imageElement.roundedCorners },
                        set: { viewModel.updateRoundedCorners($0, radius: imageElement.cornerRadius) }
                    )
                )
                .labelsHidden()
            }

            if imageElement.roundedCorners {
                HStack {
                    Text("frame.cornerRadius")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(imageElement.cornerRadius))")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { imageElement.cornerRadius },
                        set: { viewModel.updateImageAdjustment(.cornerRadius, value: $0) }
                    ),
                    in: 4...80,
                    step: 1,
                    onEditingChanged: { isEditing in
                        if isEditing {
                            viewModel.beginImageAdjustmentEditing(.cornerRadius)
                        } else {
                            viewModel.commitImageAdjustmentEditing(.cornerRadius)
                        }
                    }
                )
            }
        }
    }

    private func isMatchingStyle(_ candidateStyle: ImageFrameStyle, selectedStyle: ImageFrameStyle) -> Bool {
        candidateStyle == selectedStyle
    }
}

private struct FrameStylePreview: View {
    let style: ImageFrameStyle
    let color: Color
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.22, green: 0.26, blue: 0.34),
                            Color(red: 0.66, green: 0.48, blue: 0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            styleOverlay
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.55) : Color.black.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var styleOverlay: some View {
        switch style {
        case .simple:
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 4)
                .padding(7)

        case .double:
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color, lineWidth: 4)
                    .padding(7)
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color.opacity(0.6), lineWidth: 1.8)
                    .padding(14)
            }

        case .cornerAccent:
            CornerAccentShape()
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .padding(9)

        case .polaroid:
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.95))
                    .padding(6)
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.black.opacity(0.18))
                    .frame(width: 38, height: 22)
                    .offset(y: -4)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    .frame(width: 40, height: 24)
                    .offset(y: -4)
            }

        case .film:
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black.opacity(0.82))
                    .padding(6)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 40, height: 24)
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.78))
                            .frame(width: 5, height: 3)
                    }
                }
                .offset(y: -15)
                HStack(spacing: 4) {
                    ForEach(0..<4, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.78))
                            .frame(width: 5, height: 3)
                    }
                }
                .offset(y: 15)
            }

        case .neon:
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 3.5)
                .padding(7)
                .shadow(color: color.opacity(0.9), radius: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.62), lineWidth: 1)
                        .padding(7)
                )

        case .badge:
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(color.opacity(0.24))
                    .padding(6)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color, lineWidth: 3.5)
                    .padding(6)
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .padding(14)
            }

        case .stamp:
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.96, green: 0.92, blue: 0.80))
                    .padding(6)
                RoughFrameShape()
                    .stroke(color.opacity(0.86), lineWidth: 2.5)
                    .padding(8)
                RoughFrameShape()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .foregroundStyle(Color.black.opacity(0.12))
                    .padding(8)
            }

        case .softWhite, .glassWhite, .editorialWhite:
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.black.opacity(0.10))
                    .frame(width: 42, height: 28)

                RoundedRectangle(cornerRadius: 11)
                    .stroke(Color.white.opacity(0.22), lineWidth: 12)
                    .padding(8)

                RoundedRectangle(cornerRadius: 9)
                    .stroke(color.opacity(0.55), lineWidth: 8)
                    .padding(11)

                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                    .padding(14)
            }

        }
    }
}

private struct CornerAccentShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 2
        let length = min(rect.width, rect.height) * 0.22
        let minX = rect.minX + inset
        let minY = rect.minY + inset
        let maxX = rect.maxX - inset
        let maxY = rect.maxY - inset

        var path = Path()
        path.move(to: CGPoint(x: minX, y: minY + length))
        path.addLine(to: CGPoint(x: minX, y: minY))
        path.addLine(to: CGPoint(x: minX + length, y: minY))

        path.move(to: CGPoint(x: maxX - length, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: minY))
        path.addLine(to: CGPoint(x: maxX, y: minY + length))

        path.move(to: CGPoint(x: minX, y: maxY - length))
        path.addLine(to: CGPoint(x: minX, y: maxY))
        path.addLine(to: CGPoint(x: minX + length, y: maxY))

        path.move(to: CGPoint(x: maxX - length, y: maxY))
        path.addLine(to: CGPoint(x: maxX, y: maxY))
        path.addLine(to: CGPoint(x: maxX, y: maxY - length))
        return path
    }
}

private struct RoughFrameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let horizontalSteps = max(6, Int((rect.width / 12).rounded()))
        let verticalSteps = max(6, Int((rect.height / 12).rounded()))

        func offset(_ progress: CGFloat, seed: CGFloat) -> CGFloat {
            1.6 * (
                sin(progress * 7.2 + seed) * 0.58 +
                sin(progress * 13.1 + seed * 1.7) * 0.42
            )
        }

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + offset(0, seed: 0.4)))

        for index in 1...horizontalSteps {
            let progress = CGFloat(index) / CGFloat(horizontalSteps)
            path.addLine(to: CGPoint(
                x: rect.minX + rect.width * progress,
                y: rect.minY + offset(progress, seed: 0.4)
            ))
        }
        for index in 1...verticalSteps {
            let progress = CGFloat(index) / CGFloat(verticalSteps)
            path.addLine(to: CGPoint(
                x: rect.maxX + offset(progress, seed: 1.3),
                y: rect.minY + rect.height * progress
            ))
        }
        for index in 1...horizontalSteps {
            let progress = CGFloat(index) / CGFloat(horizontalSteps)
            path.addLine(to: CGPoint(
                x: rect.maxX - rect.width * progress,
                y: rect.maxY + offset(progress, seed: 2.1)
            ))
        }
        for index in 1...verticalSteps {
            let progress = CGFloat(index) / CGFloat(verticalSteps)
            path.addLine(to: CGPoint(
                x: rect.minX + offset(progress, seed: 2.9),
                y: rect.maxY - rect.height * progress
            ))
        }

        path.closeSubpath()
        return path
    }
}
