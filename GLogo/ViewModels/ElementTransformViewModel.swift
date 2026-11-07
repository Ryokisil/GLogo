// 同時ジェスチャーの開始値・プレビュー・終了処理を管理し、ジェスチャー1回分の変形を履歴1件にまとめる。

import Combine
import UIKit

/// 変形状態を親子で共有する。選択の切り替え・保存の受付・削除の境界では、未確定のジェスチャーを1件として確定し、
/// 古い操作の続きを終了まで無視する。
@MainActor
final class ElementTransformViewModel: ObservableObject {
    @Published private(set) var element: LogoElement?
    /// ジェスチャーの変形が未確定のあいだ true。Undo／Redo と回転リセットを止める判定に使う。
    @Published private(set) var hasPendingGestureTransform = false

    private weak var editor: (any ElementTransformApplying)?
    private var selectionObservation: AnyCancellable?
    private var gestureBasePosition: CGPoint?
    private var gestureBaseSize: CGSize?
    private var gestureBaseRotation: CGFloat?
    /// しきい値を超える変化が届き、まだ終了していない種類。画像の操作中描画の切り替えに使う。
    private var activeGestureKinds = Set<ElementGestureTransformKind>()
    /// 変化の通知が届き（しきい値未満を含む）、まだ終了していない種類。すべて終わった時点で履歴を確定する。
    private var ongoingGestureKinds = Set<ElementGestureTransformKind>()
    /// 確定前のジェスチャー操作。最初の変化の直前の値と対象の要素を、確定まで保持する。
    private var gestureSession: GestureTransformSession?
    /// 割り込みの後、古い操作の終了を待っている種類。空でないあいだは、どの種類の変化も適用しない。
    private var suppressedGestureKinds = Set<ElementGestureTransformKind>()
    private let transformUseCase = ElementTransformUseCase()
    private let imageEditingSessionUseCase = ImageEditingSessionUseCase()

    private var canEdit: Bool { editor.map { !$0.isSavingImage } ?? false }

    /// selection は現在値と以後の選択を MainActor 上で同期通知する。
    init(editor: any ElementTransformApplying, selection: AnyPublisher<LogoElement?, Never>) {
        self.editor = editor
        selectionObservation = selection.sink { [weak self] element in
            guard let self else { return }
            // 選択の通知は変更前に届くため、この時点の self.element は切り替え前の要素。
            if self.element?.id != element?.id {
                self.interruptManipulation()
            }
            self.element = element
        }
    }

    /// 保存の受付・選択の切り替え・削除で呼ぶ。画面に残る変化も Undo できるよう、未確定のジェスチャーの差分を1件として確定する。
    /// 古い操作の続き（あとから始まった種類を含む）は、すべて終わるまで無視する。
    func interruptManipulation() {
        commitGestureSession()
        suppressedGestureKinds.formUnion(ongoingGestureKinds)
        endManipulationProgress()
    }

    /// 選択枠が消えたときに呼ぶ。消えた選択枠からは終了通知が届かないため、表示していた要素の未確定の差分を確定し、
    /// 進行状態と無視の印を消す。選択中の要素と別の要素を表示していた選択枠の通知（古い選択枠から遅れて届いたもの）は、
    /// 新しく始まった操作を確定・解除しないよう無視する。
    func endGesturesForRemovedOverlay(showing elementId: UUID) {
        guard element == nil || element?.id == elementId else { return }
        commitGestureSession()
        suppressedGestureKinds.removeAll()
        endManipulationProgress()
    }

    /// 進行中の操作の状態（画像の操作中描画・開始値・基準値・進行中の種類）を終える。履歴と無視の印は扱わない。
    private func endManipulationProgress() {
        if !activeGestureKinds.isEmpty, let image = element as? ImageElement {
            imageEditingSessionUseCase.applyManipulationState(to: image, ended: true)
        }
        discardGestureSession()
        clearGestureTransformState()
    }

    /// ジェスチャーの変形が未確定のあいだと、割り込み後に古い操作が続いているあいだは受け付けない。
    /// 2本目の指のタップでダブルタップが発火しても、操作中の要素や切り替え後の要素を変えないため。
    func resetRotation() {
        guard canEdit, !hasPendingGestureTransform, suppressedGestureKinds.isEmpty, let element,
              let event = transformUseCase.resetRotationEvent(for: element) else { return }
        editor?.applyEvent(event)
    }

    private func publishPreview(_ element: LogoElement) {
        self.element = element
        editor?.updateSelectedElement(element)
    }

    /// ジェスチャーによる変形（移動・拡大縮小・回転）
    ///
    /// 最初にしきい値を超える変化が届いた時点から、通知が届いた種類がすべて終了するまでを1回の操作とし、履歴1件にまとめる。
    /// 指の本数は見ていない。SwiftUI のピンチ・回転は最後の指を離すまで続き、1本目のドラッグ中に2本目の指を置くと、
    /// ドラッグは終了通知なしで2本目の指を追い直す（どちらも1回の操作に含まれる）。
    func applyGestureTransform(
        kind: ElementGestureTransformKind,
        translation: CGSize?,
        scale: CGFloat?,
        rotation: CGFloat?,
        ended: Bool
    ) {
        if ended {
            // 終了通知は値を変えないため、保存中や未選択でも後片付けを行う。
            finishGesture(kind)
            return
        }
        // 割り込みの後は、古い操作がすべて終わるまで、どの種類の変化も適用しない。
        // あとから始まった種類も、同じ指の操作の続きとして終了を待つ。
        guard suppressedGestureKinds.isEmpty else {
            suppressedGestureKinds.insert(kind)
            return
        }
        // 保存中に始まった操作は、保存が終わった途端に途中から効き始めないよう、終了まで無視する。
        guard canEdit else {
            suppressedGestureKinds.insert(kind)
            return
        }
        guard let element else { return }
        ongoingGestureKinds.insert(kind)

        let hasMeaningfulInput: Bool = {
            switch kind {
            case .move:
                guard let translation else { return false }
                return abs(translation.width) > 0.5 || abs(translation.height) > 0.5
            case .magnify:
                guard let scale else { return false }
                return abs(scale - 1.0) > 0.001
            case .rotate:
                guard let rotation else { return false }
                return abs(rotation) > 0.001
            }
        }()

        // ジェスチャー中で入力が実質ゼロなら無視（選択タップ時の副作用を抑制）
        guard hasMeaningfulInput else { return }

        if gestureSession == nil {
            gestureSession = GestureTransformSession(elementId: element.id, start: ElementTransformState(element))
            hasPendingGestureTransform = true
        }
        gestureSession?.changedKinds.insert(kind)

        activeGestureKinds.insert(kind)
        if let imageElement = element as? ImageElement {
            imageEditingSessionUseCase.applyManipulationState(to: imageElement, ended: false)
        }

        switch kind {
        case .move:
            if gestureBasePosition == nil { gestureBasePosition = element.position }
            guard let basePos = gestureBasePosition, let delta = translation else { return }
            element.position = CGPoint(x: basePos.x + delta.width, y: basePos.y + delta.height)

        case .magnify:
            if gestureBaseSize == nil { gestureBaseSize = element.size }
            guard let baseSize = gestureBaseSize, let scale else { return }
            let clampedScale = max(scale, 0.01) // 極端な縮小を防止
            element.size = CGSize(width: baseSize.width * clampedScale, height: baseSize.height * clampedScale)

        case .rotate:
            if gestureBaseRotation == nil { gestureBaseRotation = element.rotation }
            guard let baseRot = gestureBaseRotation, let deltaRot = rotation else { return }
            element.rotation = baseRot + deltaRot
        }

        publishPreview(element)
    }

    /// 終了通知を処理する。通知の届いていない種類と、重複した終了通知は無視する。
    private func finishGesture(_ kind: ElementGestureTransformKind) {
        // 割り込み後の古い操作の終了。何も確定せず、無視の印だけを外す。
        if suppressedGestureKinds.remove(kind) != nil { return }
        guard ongoingGestureKinds.remove(kind) != nil else { return }
        clearGestureBase(for: kind)
        if activeGestureKinds.remove(kind) != nil, activeGestureKinds.isEmpty,
           let imageElement = element as? ImageElement {
            imageEditingSessionUseCase.applyManipulationState(to: imageElement, ended: true)
        }
        guard ongoingGestureKinds.isEmpty, gestureSession != nil else { return }
        commitGestureSession()
        editor?.markProjectModified()
    }

    /// 未確定の変形を、動かした種類の属性だけの履歴1件にする。変化がなければ記録しない。
    private func commitGestureSession() {
        guard let session = gestureSession else { return }
        discardGestureSession()
        guard let element, element.id == session.elementId,
              let event = transformUseCase.commitEvent(
                  from: session.start, to: element, limitedTo: session.changedKinds
              ) else { return }
        editor?.applyEvent(event)
    }

    private func discardGestureSession() {
        gestureSession = nil
        hasPendingGestureTransform = false
    }

    /// ジェスチャー変形の保持状態を初期化
    private func clearGestureTransformState() {
        gestureBasePosition = nil
        gestureBaseSize = nil
        gestureBaseRotation = nil
        activeGestureKinds.removeAll()
        ongoingGestureKinds.removeAll()
    }

    /// 指定ジェスチャーに対応する基準値を破棄
    private func clearGestureBase(for kind: ElementGestureTransformKind) {
        switch kind {
        case .move:
            gestureBasePosition = nil
        case .magnify:
            gestureBaseSize = nil
        case .rotate:
            gestureBaseRotation = nil
        }
    }
}

/// 確定前のジェスチャー操作。区間中に動かした種類だけを履歴に含める。
private struct GestureTransformSession {
    let elementId: UUID
    let start: ElementTransformState
    var changedKinds = Set<ElementGestureTransformKind>()
}
