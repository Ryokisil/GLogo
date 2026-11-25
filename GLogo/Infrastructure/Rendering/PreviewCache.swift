//
//  PreviewCache.swift
//  GLogo
//
//  概要:
//  プレビュー用のフィルター済みUIImageをハッシュキーで管理する軽量キャッシュ。
//  最新のみ実行の処理と併用し、無駄な再計算を避ける。

import UIKit

final class PreviewCache {
    private let lock = NSLock()
    private var image: UIImage?
    private var key: Int?
    private var inProgress: Bool = false

    func image(for key: Int) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        guard let cachedKey = self.key, cachedKey == key else { return nil }
        return image
    }

    func set(image: UIImage, for key: Int) {
        lock.lock()
        self.image = image
        self.key = key
        self.inProgress = false
        lock.unlock()
    }

    func markInProgress() {
        lock.lock()
        inProgress = true
        lock.unlock()
    }

    func finishProgress() {
        lock.lock()
        inProgress = false
        lock.unlock()
    }

    func isComputing() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return inProgress
    }

    func reset() {
        lock.lock()
        image = nil
        key = nil
        inProgress = false
        lock.unlock()
    }
}
