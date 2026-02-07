//
//  EditorIntroOverlay.swift
//  エディター初回ガイドのオーバーレイ表示を担当するビュー
//

import SwiftUI

/// エディター初回ガイドの表示内容を表すモデル
struct EditorIntroStep: Identifiable {
    /// ステップ識別子
    let id = UUID()
    /// ステップのタイトル
    let title: String
    /// ステップの説明文
    let message: String
    /// 補助アイコンのシステム名
    let systemImageName: String
}

/// エディター初回ガイドを表示するオーバーレイ
struct EditorIntroOverlay: View {
    /// オーバーレイの表示状態
    @Binding var isPresented: Bool
    /// 現在のステップ番号
    @Binding var stepIndex: Int
    /// 表示するステップ一覧
    let steps: [EditorIntroStep]
    /// ガイド完了時のコールバック
    let onFinish: () -> Void

    // MARK: - View

    /// ガイドの表示本体
    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                header
                content
                controls
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(Color.white)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
            .environment(\.colorScheme, .light)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("使い方ガイド")
                .font(.headline)
            Spacer()
            Button("スキップ") {
                finishGuide()
            }
            .font(.subheadline)
        }
    }

    private var content: some View {
        let step = steps[safe: stepIndex]

        return VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: step?.systemImageName ?? "questionmark")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("ステップ \(stepIndex + 1) / \(steps.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(step?.title ?? "")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(step?.message ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var controls: some View {
        HStack {
            Button("戻る") {
                stepIndex = max(0, stepIndex - 1)
            }
            .disabled(stepIndex == 0)

            Spacer()

            Button(isLastStep ? "完了" : "次へ") {
                if isLastStep {
                    finishGuide()
                } else {
                    stepIndex = min(stepIndex + 1, steps.count - 1)
                }
            }
            .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    // MARK: - Helpers

    private var isLastStep: Bool {
        stepIndex >= steps.count - 1
    }

    private func finishGuide() {
        isPresented = false
        stepIndex = 0
        onFinish()
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
