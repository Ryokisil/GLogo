///
//  EditorTopBarView.swift
//  GLogo
//
//  概要:
//  エディタ画面上部のアクションバー。
//  保存・Undo/Redo・リバート操作のUIを提供する。
//

import SwiftUI
import UIKit

/// エディタ上部アクションバー
struct EditorTopBarView: View {
    // MARK: - Properties

    /// エディタビューモデル（Undo/Redo状態の参照用）
    @ObservedObject var viewModel: EditorViewModel

    /// 保存アクション
    var onSave: () -> Void

    /// リバートアクション
    var onRevert: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Button("editor.save") {
                    onSave()
                }
                .accessibilityIdentifier("editor.topBar.saveButton")
                .help("editor.save")
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.gray.opacity(0.15))
                )

                Button(action: { viewModel.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .disabled(!viewModel.canUndo)
                .keyboardShortcut("z", modifiers: .command)
                .help("editor.help.undo")

                Button(action: { viewModel.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .disabled(!viewModel.canRedo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .help("editor.help.redo")
            }

            Spacer()

            Button("editor.revert") {
                onRevert()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.gray.opacity(0.15))
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .disabled(viewModel.isSavingImage)
        .background(
            Color(UIColor.systemBackground)
                .opacity(0.96)
                .ignoresSafeArea(edges: .top)
        )
    }
}
