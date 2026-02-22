//
//  TextPropertyPanelView.swift
//  GLogo
//
//  概要:
//  下部ツールストリップの「Text」から表示されるテキストプロパティ編集パネルです。
//  フォント・サイズ・色・整列・間隔・シャドウを
//  横スクロールのタブ選択UIとタブ別コントロールで編集します。
//

import SwiftUI

// MARK: - タブ定義

/// テキストプロパティパネルのタブ
private enum TextPropertyTab: CaseIterable, Identifiable {
    case content
    case font
    case size
    case color
    case align
    case spacing
    case effects

    var id: String { title }

    var title: String {
        switch self {
        case .content: return "Content"
        case .font: return "Font"
        case .size: return "Size"
        case .color: return "Color"
        case .align: return "Align"
        case .spacing: return "Spacing"
        case .effects: return "Effects"
        }
    }
}

/// Effects タブ内の編集セクション
private enum EffectsDetailSection: String, CaseIterable {
    case shadow = "Shadow"
    case stroke = "Stroke"
    case glow = "Glow"
}

// MARK: - TextPropertyPanelView

struct TextPropertyPanelView: View {
    @ObservedObject var viewModel: ElementViewModel
    let onClose: () -> Void
    let onOpenTextEditor: () -> Void

    @State private var selectedTab: TextPropertyTab = .content
    @State private var isShowingAllFonts = false
    @State private var pendingSheetFontName: String = ""
    @State private var selectedEffectsSection: EffectsDetailSection = .shadow

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if viewModel.textElement != nil {
                tabSelector
                tabContent
            } else {
                // テキスト未選択時のプロンプト
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "textformat")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("テキスト要素を選択してください")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
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
        .sheet(isPresented: $isShowingAllFonts) {
            allFontsSheet
        }
    }

    // MARK: - ヘッダー

    private var header: some View {
        HStack {
            Button("Reset") {
                resetCurrentTab()
            }
            .font(.subheadline.weight(.semibold))
            .disabled(viewModel.textElement == nil)

            Spacer()

            Text("Text")
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

    // MARK: - タブセレクター

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TextPropertyTab.allCases) { tab in
                    let isSelected = tab == selectedTab
                    Button {
                        selectedTab = tab
                    } label: {
                        Text(tab.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(isSelected ? .blue : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isSelected ? Color.blue.opacity(0.16) : Color.gray.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: - タブコンテンツ

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .content:
            contentTabContent
        case .font:
            fontTabContent
        case .size:
            sizeTabContent
        case .color:
            colorTabContent
        case .align:
            alignTabContent
        case .spacing:
            spacingTabContent
        case .effects:
            effectsTabContent
        }
    }

    // MARK: - Content タブ

    private var contentTabContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            Button {
                onOpenTextEditor()
            } label: {
                HStack(spacing: 8) {
                    Text(viewModel.textElement?.text ?? "テキストを入力")
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.gray.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Font タブ

    /// 人気フォントリスト
    private static let popularFonts: [String] = [
        "HelveticaNeue",
        "HelveticaNeue-Bold",
        "AvenirNext-Bold",
        "AvenirNext-DemiBold",
        "Futura-Bold",
        "Futura-Medium",
        "GillSans-Bold",
        "Georgia-Bold",
        "Menlo-Bold",
        "Courier-Bold",
        "AmericanTypewriter-Bold",
        "Copperplate-Bold"
    ]

    private var fontTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Self.popularFonts, id: \.self) { fontName in
                        fontButton(fontName)
                    }

                    // 全フォント表示ボタン
                    Button {
                        pendingSheetFontName = viewModel.textElement?.fontName ?? "HelveticaNeue"
                        isShowingAllFonts = true
                    } label: {
                        Text("More...")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 1)
            }
        }
    }

    private func fontButton(_ fontName: String) -> some View {
        let isSelected = viewModel.textElement?.fontName == fontName
        let displayName = fontName.components(separatedBy: "-").first ?? fontName

        return Button {
            guard let textElement = viewModel.textElement else { return }
            viewModel.updateFont(name: fontName, size: textElement.fontSize)
        } label: {
            Text(displayName)
                .font(.custom(fontName, size: 15))
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    /// 全フォント一覧シート
    private var allFontsSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    Text(fontPreviewText)
                        .font(.custom(pendingSheetFontName, size: 30))
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)

                    Text(pendingSheetFontName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal, 16)

                List {
                    ForEach(UIFont.familyNames.sorted(), id: \.self) { family in
                        Section(header: Text(family)) {
                            ForEach(UIFont.fontNames(forFamilyName: family), id: \.self) { fontName in
                                Button {
                                    pendingSheetFontName = fontName
                                } label: {
                                    HStack {
                                        Text(fontName)
                                            .font(.custom(fontName, size: 17))
                                        Spacer()
                                        if pendingSheetFontName == fontName {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fonts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isShowingAllFonts = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        applySelectedSheetFont()
                    }
                    .disabled(viewModel.textElement == nil)
                }
            }
        }
    }

    /// フォントシート上部に表示するプレビューテキスト
    private var fontPreviewText: String {
        let baseText = viewModel.textElement?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return baseText.isEmpty ? "Sample Text" : baseText
    }

    /// フォントシートで選択したフォントを確定
    private func applySelectedSheetFont() {
        guard let textElement = viewModel.textElement else {
            isShowingAllFonts = false
            return
        }
        let targetFontName = pendingSheetFontName.isEmpty ? textElement.fontName : pendingSheetFontName
        viewModel.updateFont(name: targetFontName, size: textElement.fontSize)
        isShowingAllFonts = false
    }

    // MARK: - Size タブ

    /// サイズプリセット
    private static let sizePresets: [(label: String, size: CGFloat)] = [
        ("S", 18),
        ("M", 36),
        ("L", 72),
        ("XL", 120)
    ]

    private var sizeTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // プリセットボタン
            HStack(spacing: 8) {
                ForEach(Self.sizePresets, id: \.label) { preset in
                    let isSelected = viewModel.textElement?.fontSize == preset.size
                    Button {
                        guard let textElement = viewModel.textElement else { return }
                        viewModel.updateFont(name: textElement.fontName, size: preset.size)
                    } label: {
                        Text(preset.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(minWidth: 44)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? Color.blue : Color.gray.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }

            // スライダー
            HStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { viewModel.textElement?.fontSize ?? 36 },
                        set: { newSize in
                            viewModel.previewTextFontSize(newSize)
                        }
                    ),
                    in: 8...200,
                    step: 1,
                    onEditingChanged: { isEditing in
                        if isEditing {
                            viewModel.beginTextFontSizeEditing()
                        } else {
                            viewModel.commitTextFontSizeEditing()
                        }
                    }
                )

                Text("\(Int(viewModel.textElement?.fontSize ?? 36))pt")
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 52, alignment: .trailing)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.12))
                    )
            }
        }
    }

    // MARK: - Color タブ

    /// プリセットカラー
    private static let presetColors: [(name: String, color: UIColor)] = [
        ("白", .white),
        ("黒", .black),
        ("赤", .systemRed),
        ("青", .systemBlue),
        ("緑", .systemGreen),
        ("黄", .systemYellow),
        ("橙", .systemOrange),
        ("紫", .systemPurple)
    ]

    private var colorTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // プリセットカラースウォッチ
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Self.presetColors, id: \.name) { preset in
                        Button {
                            viewModel.updateTextColor(preset.color)
                        } label: {
                            Circle()
                                .fill(Color(preset.color))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .overlay {
                                    if isColorMatch(preset.color) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(preset.color == .white ? .black : .white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }

            // ColorPicker
            ColorPicker(
                "Custom",
                selection: Binding(
                    get: { Color(viewModel.textElement?.textColor ?? .white) },
                    set: { newColor in
                        viewModel.updateTextColor(UIColor(newColor))
                    }
                )
            )
            .font(.subheadline)
        }
    }

    /// 現在のテキスト色とプリセット色が一致するか判定
    private func isColorMatch(_ presetColor: UIColor) -> Bool {
        guard let currentColor = viewModel.textElement?.textColor else { return false }
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        currentColor.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        presetColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let tolerance: CGFloat = 0.01
        return abs(r1 - r2) < tolerance && abs(g1 - g2) < tolerance && abs(b1 - b2) < tolerance
    }

    // MARK: - Align タブ

    private var alignTabContent: some View {
        HStack(spacing: 0) {
            ForEach(alignmentOptions, id: \.alignment) { option in
                let isSelected = viewModel.textElement?.alignment == option.alignment
                Button {
                    viewModel.updateTextAlignment(option.alignment)
                } label: {
                    Image(systemName: option.icon)
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isSelected ? Color.blue : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.gray.opacity(0.12))
        )
    }

    /// 整列オプション
    private var alignmentOptions: [(alignment: TextAlignment, icon: String)] {
        [
            (.left, "text.alignleft"),
            (.center, "text.aligncenter"),
            (.right, "text.alignright")
        ]
    }

    // MARK: - Spacing タブ

    private var spacingTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 行間スライダー
            VStack(alignment: .leading, spacing: 4) {
                Text("Line Spacing")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { viewModel.textElement?.lineSpacing ?? 1.0 },
                            set: { viewModel.previewTextLineSpacing($0) }
                        ),
                        in: 0...10,
                        step: 0.5,
                        onEditingChanged: { isEditing in
                            if isEditing {
                                viewModel.beginTextLineSpacingEditing()
                            } else {
                                viewModel.commitTextLineSpacingEditing()
                            }
                        }
                    )

                    Text(String(format: "%.1f", viewModel.textElement?.lineSpacing ?? 1.0))
                        .font(.subheadline.monospacedDigit())
                        .frame(width: 52, alignment: .trailing)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.gray.opacity(0.12))
                        )
                }
            }

            // 文字間隔スライダー
            VStack(alignment: .leading, spacing: 4) {
                Text("Letter Spacing")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Slider(
                        value: Binding(
                            get: { viewModel.textElement?.letterSpacing ?? 0.0 },
                            set: { viewModel.previewTextLetterSpacing($0) }
                        ),
                        in: -5...10,
                        step: 0.5,
                        onEditingChanged: { isEditing in
                            if isEditing {
                                viewModel.beginTextLetterSpacingEditing()
                            } else {
                                viewModel.commitTextLetterSpacingEditing()
                            }
                        }
                    )

                    Text(String(format: "%.1f", viewModel.textElement?.letterSpacing ?? 0.0))
                        .font(.subheadline.monospacedDigit())
                        .frame(width: 52, alignment: .trailing)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.gray.opacity(0.12))
                        )
                }
            }
        }
    }

    // MARK: - Effects タブ

    private var effectsTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Effects", selection: $selectedEffectsSection) {
                ForEach(EffectsDetailSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)

            switch selectedEffectsSection {
            case .shadow:
                shadowDetailSection
            case .stroke:
                strokeDetailSection
            case .glow:
                glowDetailSection
            }
        }
    }

    // MARK: - Shadow Detail

    private var shadowDetailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let shadowEffect = findShadowEffect(), let index = findShadowEffectIndex() {
                Text("Shadow")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                ColorPicker(
                    "Color",
                    selection: Binding(
                        get: { Color(shadowEffect.color) },
                        set: { newColor in
                            viewModel.updateShadowEffect(
                                atIndex: index,
                                color: UIColor(newColor),
                                offset: shadowEffect.offset,
                                blurRadius: shadowEffect.blurRadius
                            )
                        }
                    )
                )
                .font(.subheadline)

                sliderRow(label: "Blur", value: Binding(
                    get: { shadowEffect.blurRadius },
                    set: { newValue in
                        viewModel.updateShadowEffect(
                            atIndex: index, color: shadowEffect.color,
                            offset: shadowEffect.offset, blurRadius: newValue
                        )
                    }
                ), range: 0...20, step: 0.5, format: "%.1f", onEditingChanged: { isEditing in
                    if isEditing {
                        viewModel.beginShadowEffectEditing(atIndex: index)
                    } else {
                        viewModel.commitShadowEffectEditing(atIndex: index)
                    }
                })

                sliderRow(label: "X Offset", value: Binding(
                    get: { shadowEffect.offset.width },
                    set: { newValue in
                        viewModel.updateShadowEffect(
                            atIndex: index, color: shadowEffect.color,
                            offset: CGSize(width: newValue, height: shadowEffect.offset.height),
                            blurRadius: shadowEffect.blurRadius
                        )
                    }
                ), range: -20...20, step: 0.5, format: "%.1f", onEditingChanged: { isEditing in
                    if isEditing {
                        viewModel.beginShadowEffectEditing(atIndex: index)
                    } else {
                        viewModel.commitShadowEffectEditing(atIndex: index)
                    }
                })

                sliderRow(label: "Y Offset", value: Binding(
                    get: { shadowEffect.offset.height },
                    set: { newValue in
                        viewModel.updateShadowEffect(
                            atIndex: index, color: shadowEffect.color,
                            offset: CGSize(width: shadowEffect.offset.width, height: newValue),
                            blurRadius: shadowEffect.blurRadius
                        )
                    }
                ), range: -20...20, step: 0.5, format: "%.1f", onEditingChanged: { isEditing in
                    if isEditing {
                        viewModel.beginShadowEffectEditing(atIndex: index)
                    } else {
                        viewModel.commitShadowEffectEditing(atIndex: index)
                    }
                })

                // 削除ボタン
                Button(role: .destructive) {
                    if let index = findShadowEffectIndex() {
                        viewModel.removeTextEffect(atIndex: index)
                    }
                } label: {
                    Label("Remove Shadow", systemImage: "trash")
                        .font(.caption)
                }
            } else {
                Button {
                    viewModel.addTextEffect(ShadowEffect())
                } label: {
                    Label("Add Shadow", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Stroke Detail

    private var strokeDetailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let strokeEffect = findStrokeEffect(), let index = findStrokeEffectIndex() {
                Text("Stroke")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                ColorPicker(
                    "Color",
                    selection: Binding(
                        get: { Color(strokeEffect.color) },
                        set: { newColor in
                            viewModel.updateStrokeEffect(
                                atIndex: index, color: UIColor(newColor), width: strokeEffect.width
                            )
                        }
                    )
                )
                .font(.subheadline)

                sliderRow(label: "Width", value: Binding(
                    get: { strokeEffect.width },
                    set: { newValue in
                        viewModel.updateStrokeEffect(
                            atIndex: index, color: strokeEffect.color, width: newValue
                        )
                    }
                ), range: 0...20, step: 0.5, format: "%.1f", onEditingChanged: { isEditing in
                    if isEditing {
                        viewModel.beginStrokeEffectEditing(atIndex: index)
                    } else {
                        viewModel.commitStrokeEffectEditing(atIndex: index)
                    }
                })

                Button(role: .destructive) {
                    if let index = findStrokeEffectIndex() {
                        viewModel.removeTextEffect(atIndex: index)
                    }
                } label: {
                    Label("Remove Stroke", systemImage: "trash")
                        .font(.caption)
                }
            } else {
                Button {
                    viewModel.addTextEffect(StrokeEffect())
                } label: {
                    Label("Add Stroke", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Glow Detail

    private var glowDetailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let glowEffect = findGlowEffect(), let index = findGlowEffectIndex() {
                Text("Glow")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)

                ColorPicker(
                    "Color",
                    selection: Binding(
                        get: { Color(glowEffect.color) },
                        set: { newColor in
                            viewModel.updateGlowEffect(
                                atIndex: index, color: UIColor(newColor), radius: glowEffect.radius
                            )
                        }
                    )
                )
                .font(.subheadline)

                sliderRow(label: "Radius", value: Binding(
                    get: { glowEffect.radius },
                    set: { newValue in
                        viewModel.updateGlowEffect(
                            atIndex: index, color: glowEffect.color, radius: newValue
                        )
                    }
                ), range: 0...30, step: 0.5, format: "%.1f", onEditingChanged: { isEditing in
                    if isEditing {
                        viewModel.beginGlowEffectEditing(atIndex: index)
                    } else {
                        viewModel.commitGlowEffectEditing(atIndex: index)
                    }
                })

                Button(role: .destructive) {
                    if let index = findGlowEffectIndex() {
                        viewModel.removeTextEffect(atIndex: index)
                    }
                } label: {
                    Label("Remove Glow", systemImage: "trash")
                        .font(.caption)
                }
            } else {
                Button {
                    viewModel.addTextEffect(GlowEffect())
                } label: {
                    Label("Add Glow", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }
        }
    }

    /// スライダー行の共通コンポーネント
    private func sliderRow(
        label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat,
        format: String,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Slider(value: value, in: range, step: step, onEditingChanged: { isEditing in
                    onEditingChanged?(isEditing)
                })

                Text(String(format: format, value.wrappedValue))
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 52, alignment: .trailing)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.12))
                    )
            }
        }
    }

    // MARK: - ヘルパーメソッド

    /// 最初のShadowEffectを取得
    private func findShadowEffect() -> ShadowEffect? {
        viewModel.textElement?.effects.compactMap { $0 as? ShadowEffect }.first
    }

    /// 最初のShadowEffectのインデックスを取得
    private func findShadowEffectIndex() -> Int? {
        viewModel.textElement?.effects.firstIndex(where: { $0 is ShadowEffect })
    }

    /// Stroke エフェクトを取得
    ///
    /// - Parameters: なし
    /// - Returns: Stroke エフェクト。存在しない場合は nil
    private func findStrokeEffect() -> StrokeEffect? {
        viewModel.textElement?.effects.compactMap { $0 as? StrokeEffect }.first
    }

    /// Stroke エフェクトのインデックスを取得
    ///
    /// - Parameters: なし
    /// - Returns: Stroke エフェクトのインデックス。存在しない場合は nil
    private func findStrokeEffectIndex() -> Int? {
        viewModel.textElement?.effects.firstIndex(where: { $0 is StrokeEffect })
    }

    /// 最初のGlowEffectを取得
    private func findGlowEffect() -> GlowEffect? {
        viewModel.textElement?.effects.compactMap { $0 as? GlowEffect }.first
    }

    /// 最初のGlowEffectのインデックスを取得
    private func findGlowEffectIndex() -> Int? {
        viewModel.textElement?.effects.firstIndex(where: { $0 is GlowEffect })
    }

    /// 現在のタブの値をリセット
    private func resetCurrentTab() {
        guard viewModel.textElement != nil else { return }
        switch selectedTab {
        case .content:
            viewModel.updateText("Text")
        case .font:
            viewModel.updateFont(name: "HelveticaNeue", size: viewModel.textElement?.fontSize ?? 36)
        case .size:
            viewModel.updateFont(name: viewModel.textElement?.fontName ?? "HelveticaNeue", size: 36.0)
        case .color:
            viewModel.updateTextColor(.white)
        case .align:
            viewModel.updateTextAlignment(.center)
        case .spacing:
            viewModel.updateLineSpacing(1.0)
            viewModel.updateLetterSpacing(0.0)
        case .effects:
            switch selectedEffectsSection {
            case .shadow:
                if let index = findShadowEffectIndex(), let effect = findShadowEffect() {
                    viewModel.updateShadowEffect(
                        atIndex: index,
                        color: .black,
                        offset: CGSize(width: 2, height: 2),
                        blurRadius: 3.0
                    )
                    if !effect.isEnabled {
                        viewModel.updateTextEffect(atIndex: index, isEnabled: true)
                    }
                }
            case .stroke:
                if let index = findStrokeEffectIndex(), let effect = findStrokeEffect() {
                    viewModel.updateStrokeEffect(atIndex: index, color: .black, width: 2.0)
                    if !effect.isEnabled {
                        viewModel.updateTextEffect(atIndex: index, isEnabled: true)
                    }
                }
            case .glow:
                if let index = findGlowEffectIndex(), let effect = findGlowEffect() {
                    viewModel.updateGlowEffect(atIndex: index, color: .white, radius: 5.0)
                    if !effect.isEnabled {
                        viewModel.updateTextEffect(atIndex: index, isEnabled: true)
                    }
                }
            }
        }
    }
}
