//
//  RenderScheduler.swift
//  GLogo
//
//  概要:
//  最新のみ実行するデバウンス付きスケジューラ。
//  スライダーやトーンカーブ操作時の最終品質処理をまとめ、不要な連続実行を防ぐ。

import Foundation

/// 再描画予約を置換・取消できる能力。呼び出しは MainActor に限定する。
@MainActor
protocol RenderScheduling: AnyObject {
    func schedule(_ block: @escaping () -> Void)
    func cancel()
}

/// 最新値だけを実行するシンプルなデバウンス＋latest-onlyスケジューラ。
final class RenderScheduler: RenderScheduling {
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    private let debounce: TimeInterval

    init(label: String = "com.glogo.renderScheduler", debounce: TimeInterval = 0.1) {
        self.queue = DispatchQueue(label: label, qos: .userInitiated)
        self.debounce = debounce
    }

    func schedule(_ block: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem(block: block)
        workItem = item
        queue.asyncAfter(deadline: .now() + debounce, execute: item)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}
