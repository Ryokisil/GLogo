//
//  DeleteFadeEffect.swift
//  GLogo
//
//  概要:
//  要素削除時に表示するフェードアウトエフェクト。
//  削除対象の要素をスナップショットとしてオーバーレイに重ね、
//  縮小+透明化のアニメーションで自然に消滅させる。
//

import SwiftUI
import UIKit

/// 削除エフェクトの状態
struct DeleteEffectState {
    /// エフェクト表示中かどうか
    var isActive = false
    /// 要素のスナップショット画像
    var snapshot: UIImage?
    /// 要素の表示フレーム（キャンバス座標系）
    var frame: CGRect = .zero
}

/// フェードアウト削除エフェクトビュー
struct DeleteFadeEffect: View {
    /// 要素のスナップショット
    let snapshot: UIImage
    /// 要素の表示フレーム
    let frame: CGRect
    /// エフェクト完了時のコールバック
    let onComplete: () -> Void

    /// アニメーション進行フラグ
    @State private var isAnimating = false

    // MARK: - View

    var body: some View {
        Image(uiImage: snapshot)
            .resizable()
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
            .scaleEffect(isAnimating ? 0.6 : 1.0)
            .opacity(isAnimating ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeIn(duration: 0.35)) {
                    isAnimating = true
                }
                // アニメーション完了後にコールバック
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onComplete()
                }
            }
    }
}

// MARK: - スナップショット生成

extension LogoElement {
    /// 要素を UIImage にスナップショットする
    /// - Returns: 描画結果の画像（描画不可時は nil）
    func renderSnapshot() -> UIImage? {
        let size = self.size
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            let cgContext = ctx.cgContext
            // 要素の position 分を逆オフセットして原点基準で描画
            cgContext.translateBy(x: -self.position.x, y: -self.position.y)
            self.draw(in: cgContext)
        }
    }
}
