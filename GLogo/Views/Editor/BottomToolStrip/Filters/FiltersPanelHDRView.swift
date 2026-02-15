//
//  FiltersPanelHDRView.swift
//  GLogo
//
//  概要:
//  HDRモード専用のフィルターパネル本体。
//  カテゴリ選択・プリセットプレビュー・適用ロジックを担当する。
//

import SwiftUI

struct FiltersPanelHDRView: View {
    @ObservedObject var viewModel: ElementViewModel

    /// カテゴリ絞り込み（nil = 全表示）
    @State private var selectedCategory: FilterCategory?
    /// プリセットIDごとのプレビュー画像
    @State private var previewImages: [String: UIImage] = [:]
    /// プレビュー生成中のプリセットID
    @State private var loadingPresetIds: Set<String> = []
    /// 前回プレビュー生成時の .task(id:) キー
    @State private var loadedPreviewKey: String?

    /// プリセットが1つ以上あるカテゴリのみ表示
    private var availableCategories: [FilterCategory] {
        HDRFilterCatalog.categories
    }

    /// 選択カテゴリで絞り込んだプリセット一覧
    private var filteredPresets: [FilterPreset] {
        if let category = selectedCategory {
            return HDRFilterCatalog.presets(for: category)
        }
        return HDRFilterCatalog.allPresets
    }

    /// manual 調整値の変化を検知するフィンガープリント
    private var adjustmentFingerprint: Int {
        guard let img = viewModel.imageElement else { return 0 }
        return FiltersPanelSDRView.adjustmentFingerprint(for: img)
    }

    var body: some View {
        Group {
            if viewModel.imageElement != nil {
                categorySelector
                presetCardsSection
            } else {
                Text("Select an image to apply HDR filters.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .task(id: "\(viewModel.imageElement?.id.uuidString ?? "")_hdr_\(adjustmentFingerprint)") {
            await loadPreviewImagesIfNeeded()
        }
    }

    // MARK: - Private Views

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryPill(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(availableCategories) { category in
                    categoryPill(
                        title: category.displayName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func categoryPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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

    private var presetCardsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filteredPresets) { preset in
                    presetCard(preset)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func presetCard(_ preset: FilterPreset) -> some View {
        let isSelected = viewModel.appliedFilterPresetId == preset.id

        return Button {
            viewModel.applyFilterPreset(preset)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(preset.previewColor))
                        .frame(width: 72, height: 72)

                    if let previewImage = previewImages[preset.id] {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else if loadingPresetIds.contains(preset.id) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2.5)
                )

                Text(preset.name)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Private Methods

    /// 選択中画像に対するHDRプリセットプレビューを生成
    @MainActor
    private func loadPreviewImagesIfNeeded() async {
        guard viewModel.imageElement != nil else {
            loadedPreviewKey = nil
            previewImages.removeAll()
            loadingPresetIds.removeAll()
            return
        }

        let currentKey = "\(viewModel.imageElement?.id.uuidString ?? "")_hdr_\(adjustmentFingerprint)"
        if loadedPreviewKey != currentKey {
            loadedPreviewKey = currentKey
            previewImages.removeAll()
            loadingPresetIds.removeAll()
        }

        let targetSize = CGSize(width: 72, height: 72)
        for preset in HDRFilterCatalog.allPresets {
            if Task.isCancelled { return }
            if previewImages[preset.id] != nil { continue }

            loadingPresetIds.insert(preset.id)
            let preview = await viewModel.generateFilterPreview(for: preset, targetSize: targetSize)
            loadingPresetIds.remove(preset.id)

            if Task.isCancelled { return }
            if let preview {
                previewImages[preset.id] = preview
            }
        }
    }
}
