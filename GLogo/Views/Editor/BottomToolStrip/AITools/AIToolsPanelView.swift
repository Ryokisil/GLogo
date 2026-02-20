//
//  AIToolsPanelView.swift
//  GLogo
//
//  概要:
//  エディタ下部のAI Toolsカードを提供します。
//  背景除去と背景ぼかしに関連する操作を1つのカードに集約します。
//

import SwiftUI

/// AI Toolsパネルで扱うタブ種別です。
private enum AIToolsTab: CaseIterable, Identifiable {
    case backgroundRemoval
    case backgroundBlur

    var id: String { title }

    /// タブに表示するタイトル文字列を返します。
    /// - Parameters: なし
    /// - Returns: タブ表示用のタイトル文字列
    var title: String {
        switch self {
        case .backgroundRemoval:
            return "Background Remove"
        case .backgroundBlur:
            return "Background Blur"
        }
    }
}

/// エディタ下部のAI Toolsパネルを表示するビューです。
struct AIToolsPanelView: View {
    @ObservedObject var viewModel: ElementViewModel
    let onClose: () -> Void
    let onOpenManualBackgroundRemoval: () -> Void

    @State private var selectedTab: AIToolsTab = .backgroundRemoval

    private var hasSelectedImage: Bool {
        viewModel.imageElement != nil
    }

    private var hasBlurMask: Bool {
        viewModel.imageElement?.backgroundBlurMaskData != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if hasSelectedImage {
                tabSelector
                tabContent
            } else {
                Text("Select an image to use AI tools.")
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
                resetCurrentTab()
            }
            .font(.subheadline.weight(.semibold))
            .disabled(!canResetCurrentTab())

            Spacer()

            Text("AI Tools")
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

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AIToolsTab.allCases) { tab in
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

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .backgroundRemoval:
            backgroundRemovalContent
        case .backgroundBlur:
            backgroundBlurContent
        }
    }

    private var backgroundRemovalContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Remove background with AI or open the editor for manual editing.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Button {
                    viewModel.requestAIBackgroundRemoval()
                } label: {
                    if viewModel.isProcessingAI {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    } else {
                        Label("AI Remove", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasSelectedImage || viewModel.isProcessingAI)

                Button {
                    onOpenManualBackgroundRemoval()
                } label: {
                    Label("Manual Edit", systemImage: "paintbrush.pointed")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(!hasSelectedImage || viewModel.isProcessingAI)
            }
        }
    }

    private var backgroundBlurContent: some View {
        let radiusBinding = Binding(
            get: { viewModel.imageElement?.backgroundBlurRadius ?? 0 },
            set: { newValue in
                viewModel.updateImageAdjustment(.backgroundBlurRadius, value: newValue)
            }
        )

        return VStack(alignment: .leading, spacing: 12) {
            Text("Blur Radius")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Slider(
                    value: radiusBinding,
                    in: 0...48,
                    step: 1,
                    onEditingChanged: { isEditing in
                        if isEditing {
                            viewModel.beginImageAdjustmentEditing(.backgroundBlurRadius)
                        } else {
                            viewModel.commitImageAdjustmentEditing(.backgroundBlurRadius)
                        }
                    }
                )

                Text("\(Int(radiusBinding.wrappedValue))")
                    .font(.subheadline.monospacedDigit())
                    .frame(width: 52, alignment: .trailing)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.12))
                    )
            }
            .disabled(!hasSelectedImage)

            HStack(spacing: 8) {
                Button {
                    viewModel.requestAIBackgroundBlur()
                } label: {
                    if viewModel.isProcessingAI {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    } else {
                        Label("Generate AI Mask", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasSelectedImage || viewModel.isProcessingAI)

                Button {
                    viewModel.requestBackgroundBlurMaskEdit()
                } label: {
                    Label("Edit Mask", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(!hasSelectedImage)
            }

            Button {
                viewModel.removeBackgroundBlurMask()
            } label: {
                Label("Clear Blur Mask", systemImage: "xmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .disabled(!hasSelectedImage || !hasBlurMask)
        }
    }

    /// 現在選択中のタブがリセット可能かどうかを判定します。
    /// - Parameters: なし
    /// - Returns: リセット可能な場合は`true`
    private func canResetCurrentTab() -> Bool {
        guard let imageElement = viewModel.imageElement else { return false }
        switch selectedTab {
        case .backgroundRemoval:
            // 背景除去タブは即時アクションのみで、保持状態を持たないためリセット対象はありません。
            return false
        case .backgroundBlur:
            return imageElement.backgroundBlurRadius != 0 || imageElement.backgroundBlurMaskData != nil
        }
    }

    /// 現在選択中のタブ状態を既定値へ戻します。
    private func resetCurrentTab() {
        guard let imageElement = viewModel.imageElement else { return }
        switch selectedTab {
        case .backgroundRemoval:
            // 背景除去タブはリセット対象の内部状態を持たないため何もしません。
            return
        case .backgroundBlur:
            // 履歴イベントのノイズを避けるため、変更がある場合のみ更新します。
            if imageElement.backgroundBlurRadius != 0 {
                viewModel.beginImageAdjustmentEditing(.backgroundBlurRadius)
                viewModel.updateImageAdjustment(.backgroundBlurRadius, value: 0)
                viewModel.commitImageAdjustmentEditing(.backgroundBlurRadius)
            }
            // ぼかしマスクが存在する場合のみ削除します。
            if imageElement.backgroundBlurMaskData != nil {
                viewModel.removeBackgroundBlurMask()
            }
        }
    }
}
