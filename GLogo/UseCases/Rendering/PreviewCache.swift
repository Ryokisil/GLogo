//
//  PreviewCache.swift
//  GLogo
//
//  概要:
//  プレビュー用のフィルター済みUIImageをハッシュキーで管理する軽量キャッシュ。
//  最新のみ実行の処理と併用し、無駄な再計算を避ける。

import UIKit

final class PreviewCache {
    private var image: UIImage?
    private var key: Int?
    private var inProgress: Bool = false

    func image(for key: Int) -> UIImage? {
        guard let cachedKey = self.key, cachedKey == key else { return nil }
        return image
    }

    func set(image: UIImage, for key: Int) {
        self.image = image
        self.key = key
        self.inProgress = false
    }

    func markInProgress() {
        inProgress = true
    }

    func finishProgress() {
        inProgress = false
    }

    func isComputing() -> Bool {
        return inProgress
    }

    func reset() {
        image = nil
        key = nil
        inProgress = false
    }
}
