//
//  TextEditDialog.swift
//  GLogo
//
//  概要:
//  テキスト要素をダブルタップした際に表示されるモーダルダイアログ。
//  画面全体にオーバーレイされ、テキストの編集、キャンセル、確定を作る。
//

import SwiftUI

/// テキスト編集モーダルダイアログ
struct TextEditDialog: View {
    // MARK: - プロパティ
    
    /// 編集するテキスト
    @State private var editingText: String
    
    /// テキストフィールドのフォーカス状態
    @FocusState private var isTextFieldFocused: Bool
    
    /// 編集完了時のコールバック
    let onEditComplete: (String) -> Void
    
    /// キャンセル時のコールバック
    let onCancel: () -> Void
    
    // MARK: - 初期化
    
    init(
        initialText: String,
        onEditComplete: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._editingText = State(initialValue: initialText)
        self.onEditComplete = onEditComplete
        self.onCancel = onCancel
    }
    
    // MARK: - ビュー
    
    var body: some View {
        ZStack {
            // 背景オーバーレイ
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // ダイアログコンテンツ
            VStack(spacing: 0) {
                // タイトル部分
                VStack(spacing: 8) {
                    Text("Text")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // テキスト入力フィールド
                    TextField("Double tap here to change text", text: $editingText, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(UIColor.systemGray6))
                        )
                        .lineLimit(1...3)
                        .frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // 区切り線
                Rectangle()
                    .fill(Color(UIColor.separator))
                    .frame(height: 0.5)
                
                // ボタン部分
                HStack(spacing: 0) {
                    // キャンセルボタン
                    Button(action: {
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 16,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                        .fill(Color(UIColor.systemBackground))
                    )
                    
                    // 区切り線
                    Rectangle()
                        .fill(Color(UIColor.separator))
                        .frame(width: 0.5)
                    
                    // OKボタン
                    Button(action: {
                        onEditComplete(editingText)
                    }) {
                        Text("OK")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 16,
                            topTrailingRadius: 0
                        )
                        .fill(Color(UIColor.systemBackground))
                    )
                }
            }
            .frame(width: 280, height: 143)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.systemBackground))
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .onAppear {
            // ダイアログ表示時にテキストフィールドにフォーカス
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
        .onSubmit {
            // Enterキーで確定
            onEditComplete(editingText)
        }
    }
}

/// プレビュー
struct TextEditDialog_Previews: PreviewProvider {
    static var previews: some View {
        TextEditDialog(
            initialText: "サンプルテキスト",
            onEditComplete: { text in
                print("編集完了: \(text)")
            },
            onCancel: {
                print("キャンセル")
            }
        )
    }
}
