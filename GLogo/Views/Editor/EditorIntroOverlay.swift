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
            // 背景ディム
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // カード
            VStack(spacing: 24) {
                header
                heroIcon
                stepContent
                progressDots
                controls
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background {
                ZStack {
                    // パステルブルーのベース
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(red: 0.76, green: 0.87, blue: 1.0))
                    // パステルパープルをアルファで重ね、柔らかく混ぜ合わせる
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 0.80, green: 0.72, blue: 0.98).opacity(0.75), location: 0),
                                    .init(color: Color(red: 0.80, green: 0.72, blue: 0.98).opacity(0.0), location: 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.5), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            // 背景が常にパステル系のため、テキスト色をライトモード基準に固定
            .environment(\.colorScheme, .light)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: stepIndex)
    }

    // MARK: - Subviews

    /// ガイドタイトルとスキップボタン
    private var header: some View {
        HStack {
            Text("使い方ガイド")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Spacer()

            Button("スキップ") {
                finishGuide()
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    /// グラデーション背景のステップアイコン
    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)
                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)

            Image(systemName: steps[safe: stepIndex]?.systemImageName ?? "questionmark")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .id("icon-\(stepIndex)")
                .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    /// ステップのタイトルと説明
    private var stepContent: some View {
        VStack(spacing: 8) {
            Text(steps[safe: stepIndex]?.title ?? "")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)

            Text(steps[safe: stepIndex]?.message ?? "")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .id("content-\(stepIndex)")
        .transition(.opacity)
    }

    /// ステップ進捗のドットインジケーター
    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<steps.count, id: \.self) { index in
                Capsule()
                    .fill(index == stepIndex ? Color.blue : Color.primary.opacity(0.15))
                    .frame(width: index == stepIndex ? 20 : 8, height: 8)
            }
        }
    }

    /// 戻る・次へナビゲーションボタン
    private var controls: some View {
        HStack(spacing: 12) {
            if stepIndex > 0 {
                Button {
                    stepIndex = max(0, stepIndex - 1)
                } label: {
                    Text("戻る")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.primary.opacity(0.06))
                        )
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            Button {
                if isLastStep {
                    finishGuide()
                } else {
                    stepIndex = min(stepIndex + 1, steps.count - 1)
                }
            } label: {
                Text(isLastStep ? "完了" : "次へ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.blue)
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 6, y: 3)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    /// 最終ステップかどうか
    private var isLastStep: Bool {
        stepIndex >= steps.count - 1
    }

    /// ガイドを終了する
    private func finishGuide() {
        withAnimation(.easeOut(duration: 0.25)) {
            isPresented = false
        }
        stepIndex = 0
        onFinish()
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
