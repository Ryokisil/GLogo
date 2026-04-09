//
//  FiltersPanelHDRView.swift
//  GLogo
//
//  概要:
//  HDRモード専用のフィルターパネル本体。
//  カテゴリ選択・プリセットプレビュー・適用ロジックを担当する。
//

import SwiftUI

/// Favorites / All / カテゴリの選択肢
private enum HDRFilterSection: Hashable {
    case favorites
    case all
    case category(FilterCategory)
}

struct FiltersPanelHDRView: View {
    @ObservedObject var viewModel: ElementViewModel

    /// セクション選択（デフォルト = All）
    @State private var selectedSection: HDRFilterSection = .all
    /// プリセットIDごとのプレビュー画像
    @State private var previewImages: [String: UIImage] = [:]
    /// プレビュー生成中のプリセットID
    @State private var loadingPresetIds: Set<String> = []
    /// 前回プレビュー生成時の .task(id:) キー
    @State private var loadedPreviewKey: String?
    /// お気に入り ID 集合
    @State private var favoriteIds: Set<String> = []

    /// プリセットが1つ以上あるカテゴリのみ表示
    private var availableCategories: [FilterCategory] {
        HDRFilterCatalog.categories
    }

    /// 選択セクションで絞り込んだプリセット一覧
    private var filteredPresets: [FilterPreset] {
        switch selectedSection {
        case .favorites:
            return HDRFilterCatalog.allPresets.filter { favoriteIds.contains($0.id) }
        case .all:
            return HDRFilterCatalog.allPresets
        case .category(let cat):
            return HDRFilterCatalog.presets(for: cat)
        }
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
                    .transaction { $0.animation = nil }
                presetCardsSection
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text("filters.selectImageHDR")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear { favoriteIds = FilterFavoritesStore().loadFavoriteIds() }
        .task(id: "\(viewModel.imageElement?.id.uuidString ?? "")_hdr_\(adjustmentFingerprint)") {
            await loadPreviewImagesIfNeeded()
        }
    }

    // MARK: - Private Views

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryPill(titleKey: "filters.category.favorites", isSelected: selectedSection == .favorites) {
                    selectedSection = .favorites
                }
                categoryPill(titleKey: "filters.category.all", isSelected: selectedSection == .all) {
                    selectedSection = .all
                }
                ForEach(availableCategories) { category in
                    categoryPill(
                        titleKey: LocalizedStringKey(category.localizationKey),
                        isSelected: selectedSection == .category(category)
                    ) {
                        selectedSection = .category(category)
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func categoryPill(titleKey: LocalizedStringKey, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titleKey)
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
        Group {
            if filteredPresets.isEmpty && selectedSection == .favorites {
                Text("filters.favorites.empty")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filteredPresets) { preset in
                            presetCard(preset)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: favoriteIds)
    }

    private func presetCard(_ preset: FilterPreset) -> some View {
        let isSelected = viewModel.appliedFilterPresetId == preset.id
        let isFav = favoriteIds.contains(preset.id)

        return VStack(spacing: 6) {
            Button {
                viewModel.applyFilterPreset(preset)
            } label: {
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
            }
            .buttonStyle(.plain)
            // 星アイコン（お気に入りトグル） — カード適用ボタンと独立した兄弟ビュー
            .overlay(alignment: .topTrailing) {
                Button {
                    var s = FilterFavoritesStore()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        favoriteIds = s.toggle(preset.id)
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: isFav ? "star.fill" : "star")
                            .contentTransition(.symbolEffect(.replace))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isFav ? .yellow : .white.opacity(0.8))
                            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            .padding(5)
                    }
                    .frame(width: 40, height: 40, alignment: .topTrailing)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("editor.filterPreset.\(preset.id).favorite")
                .accessibilityLabel(Text(isFav ? "filters.favorite.remove" : "filters.favorite.add"))
            }

            Text(LocalizedStringKey(preset.localizationKey))
                .font(.caption2.weight(.medium))
                .foregroundColor(isSelected ? .blue : .primary)
                .lineLimit(1)
        }
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
