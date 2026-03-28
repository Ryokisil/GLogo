///
//  EditorOverlayToolbarView.swift
//  GLogo
//
//  概要:
//  キャンバス上に浮かぶオーバーレイツールバー。
//  モードセレクタ（画像追加・削除・画像役割切替）と設定ボタンを提供する。
//

import SwiftUI
import UIKit

/// キャンバス上のオーバーレイツールバー
struct EditorOverlayToolbarView: View {
    // MARK: - Properties

    /// エディタビューモデル
    @ObservedObject var viewModel: EditorViewModel

    /// 画像ピッカー/クロップシートの表示制御
    @Binding var activeSheet: ActiveSheet?

    /// 削除エフェクトの状態
    @Binding var deleteEffect: DeleteEffectState

    /// 確認ダイアログ表示アクション
    var onShowConfirmation: (_ message: LocalizedStringKey, _ action: @escaping () -> Void) -> Void

    /// 設定画面を開くアクション
    var onOpenAppSettings: () -> Void

    // MARK: - Body

    var body: some View {
        HStack {
            modeSelector

            Spacer()

            viewControls
        }
        .padding(8)
        .background(Color(UIColor.systemBackground).opacity(0.9))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    // MARK: - Private Views

    /// モードセレクタ（画像追加・削除・画像役割切替）
    private var modeSelector: some View {
        HStack(spacing: 12) {
            // 画像インポートモード
            Button(action: {
                viewModel.editorMode = .imageImport
                activeSheet = .imagePicker
            }) {
                Image(systemName: "photo")
                    .foregroundColor(viewModel.editorMode == .imageImport ? .blue : .primary)
            }
            .help("editor.help.addImage")

            // 削除モード
            Button(action: {
                if let element = viewModel.selectedElement {
                    onShowConfirmation("editor.deleteConfirmation") {
                        deleteEffect.snapshot = element.renderSnapshot()
                        deleteEffect.frame = element.frame
                        deleteEffect.isActive = true
                        viewModel.deleteSelectedElement()
                    }
                } else {
                    viewModel.editorMode = .delete
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(viewModel.editorMode == .delete ? .red : .primary)
            }
            .help("editor.help.deleteTool")

            // 画像役割切り替え（ベース/オーバーレイ）
            if let selectedElement = viewModel.selectedElement,
               let imageElement = selectedElement as? ImageElement {
                Button(action: {
                    if !imageElement.isBaseImage {
                        viewModel.toggleImageRole(imageElement)
                    }
                }) {
                    Image(systemName: imageElement.isBaseImage ? "star.fill" : "star")
                        .foregroundColor(imageElement.isBaseImage ? .yellow : .primary)
                        .opacity(imageElement.isBaseImage ? 0.7 : 1.0)
                }
                .disabled(imageElement.isBaseImage)
                .help(imageElement.isBaseImage ? String(localized: "editor.help.baseImageLocked") : String(localized: "editor.help.setBaseImage"))
            }
        }
    }

    /// 設定ボタン
    private var viewControls: some View {
        HStack(spacing: 12) {
            Button(action: onOpenAppSettings) {
                Image(systemName: "gearshape")
                    .foregroundColor(.primary)
            }
            .help("editor.help.appSettings")
        }
    }
}
