///
//  ImageListRailView.swift
//  GLogo
//
//  概要:
//  キャンバス左側に表示される画像一覧レール。
//  インポート済み ImageElement のサムネイルを縦並びで表示し、
//  タップで選択、ドラッグで重なり順の並べ替えを提供する。
//  上が前面、下が背面。
//

import SwiftUI
import UniformTypeIdentifiers

/// 画像一覧レール（重なり順管理パネル）
struct ImageListRailView: View {
    // MARK: - Properties

    /// エディタビューモデル
    @ObservedObject var viewModel: EditorViewModel

    /// レール幅
    private let railWidth: CGFloat = 72

    /// ドラッグ中の画像要素ID
    @State private var draggedImageID: UUID?

    /// 現在のドロップ候補画像要素ID
    @State private var dropTargetImageID: UUID?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if viewModel.imageElements.isEmpty {
                emptyState
            } else {
                imageList
            }
        }
        .frame(width: railWidth)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(radius: 4)
    }

    // MARK: - Private Views

    /// ヘッダー（タイトル）
    private var header: some View {
        VStack(spacing: 2) {
            Image(systemName: "photo.stack")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("画像")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }

    /// 画像が0枚のときの空表示
    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "photo.badge.plus")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("画像なし")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
        .padding(.vertical, 16)
    }

    /// 画像サムネイルリスト（ドラッグ並べ替え対応）
    private var imageList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            // ヘッダーラベル
            Text("前面")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .padding(.top, 4)

            LazyVStack(spacing: 6) {
                ForEach(viewModel.imageElements, id: \.id) { imageElement in
                    thumbnailCell(for: imageElement)
                        .onDrag {
                            draggedImageID = imageElement.id
                            return NSItemProvider(object: imageElement.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [UTType.plainText],
                            delegate: ImageRailThumbnailDropDelegate(
                                targetImageID: imageElement.id,
                                viewModel: viewModel,
                                draggedImageID: $draggedImageID,
                                dropTargetImageID: $dropTargetImageID
                            )
                        )
                }
            }
            .padding(.horizontal, 6)

            Text("背面")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
        }
    }

    /// 個別画像サムネイルセル
    private func thumbnailCell(for imageElement: ImageElement) -> some View {
        let isSelected = viewModel.selectedElement?.id == imageElement.id
        let isDropTarget = dropTargetImageID == imageElement.id && draggedImageID != imageElement.id

        return Button {
            viewModel.selectElement(imageElement)
        } label: {
            Group {
                // サムネイル画像
                if let uiImage = imageElement.originalImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: railWidth - 16, height: railWidth - 16)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: railWidth - 16, height: railWidth - 16)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor(isSelected: isSelected, isDropTarget: isDropTarget), lineWidth: isSelected || isDropTarget ? 2.5 : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("imageRail.thumbnail.\(imageElement.id.uuidString)")
        .accessibilityLabel("画像")
    }

    /// サムネイル枠線色を返す
    /// - Parameters:
    ///   - isSelected: 選択中かどうか
    ///   - isDropTarget: ドロップ候補かどうか
    /// - Returns: 枠線色
    private func borderColor(isSelected: Bool, isDropTarget: Bool) -> Color {
        if isDropTarget {
            return .orange
        }
        return isSelected ? .accentColor : .clear
    }
}

/// 画像サムネイルのドロップ先制御
private struct ImageRailThumbnailDropDelegate: DropDelegate {
    /// ドロップ先画像要素ID
    let targetImageID: UUID

    /// エディタビューモデル
    let viewModel: EditorViewModel

    /// ドラッグ中の画像要素ID
    @Binding var draggedImageID: UUID?

    /// 現在のドロップ候補画像要素ID
    @Binding var dropTargetImageID: UUID?

    /// ドロップ進行中の提案を返す
    /// - Parameters:
    ///   - info: ドロップ情報
    /// - Returns: move 操作提案
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    /// ドロップ候補に入ったときの処理
    /// - Parameters:
    ///   - info: ドロップ情報
    /// - Returns: なし
    func dropEntered(info: DropInfo) {
        guard draggedImageID != targetImageID else { return }
        dropTargetImageID = targetImageID
    }

    /// ドロップ候補から外れたときの処理
    /// - Parameters:
    ///   - info: ドロップ情報
    /// - Returns: なし
    func dropExited(info: DropInfo) {
        guard dropTargetImageID == targetImageID else { return }
        dropTargetImageID = nil
    }

    /// ドロップ確定時に画像順を更新する
    /// - Parameters:
    ///   - info: ドロップ情報
    /// - Returns: ドロップを処理したかどうか
    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedImageID = nil
            dropTargetImageID = nil
        }

        guard let draggedImageID else { return false }
        viewModel.reorderImageElement(draggedImageID: draggedImageID, to: targetImageID)
        return true
    }

    /// ドロップ可否を判定する
    /// - Parameters:
    ///   - info: ドロップ情報
    /// - Returns: 同一要素以外なら true
    func validateDrop(info: DropInfo) -> Bool {
        guard let draggedImageID else { return false }
        return draggedImageID != targetImageID
    }
}
