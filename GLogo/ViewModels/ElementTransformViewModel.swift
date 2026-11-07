// 座標操作と同時ジェスチャーの開始値・プレビュー・終了処理を管理し、ジェスチャー1回分の変形を履歴1件にまとめる。

import Combine
import UIKit

/// 変形状態を親子で共有し、選択 ID と保存ロックの境界で開始値を破棄する。
@MainActor
final class ElementTransformViewModel: ObservableObject {
    @Published private(set) var element: LogoElement?
    @Published private(set) var manipulationType: ElementManipulationType = .none
    /// ジェスチャーの変形が未確定のあいだ true。Undo／Redo と回転リセットを止める判定に使う。
    @Published private(set) var hasPendingGestureTransform = false

    private weak var editor: (any ElementTransformApplying)?
    private var selectionObservation: AnyCancellable?
    private var manipulationStartPoint: CGPoint = .zero
    private var manipulationStartState: ElementTransformState?
    private var gestureBasePosition: CGPoint?
    private var gestureBaseSize: CGSize?
    private var gestureBaseRotation: CGFloat?
    /// しきい値を超える変化が届き、まだ終了していない種類。画像の操作中描画の切り替えに使う。
    private var activeGestureKinds = Set<ElementGestureTransformKind>()
    /// 変化の通知が届き（しきい値未満を含む）、まだ終了していない種類。すべて終わった時点で履歴を確定する。
    private var ongoingGestureKinds = Set<ElementGestureTransformKind>()
    /// 確定前のジェスチャー操作。最初の変化の直前の値と対象の要素を、確定まで保持する。
    private var gestureSession: GestureTransformSession?
    private weak var renderingProject: LogoProject?
    private let transformUseCase = ElementTransformUseCase()
    private let manipulationRenderingUseCase = ManipulationRenderingUseCase()
    private let imageEditingSessionUseCase = ImageEditingSessionUseCase()

    private var canEdit: Bool { editor.map { !$0.isSavingImage } ?? false }

    /// selection は現在値と以後の選択を MainActor 上で同期通知する。
    init(editor: any ElementTransformApplying, selection: AnyPublisher<LogoElement?, Never>) {
        self.editor = editor
        selectionObservation = selection.sink { [weak self] element in
            guard let self else { return }
            if self.element?.id != element?.id {
                self.cancelManipulation()
            }
            self.element = element
        }
    }

    func startManipulation(_ type: ElementManipulationType, at point: CGPoint) {
        guard canEdit, let element else { return }
        manipulationType = type
        manipulationStartPoint = point
        manipulationStartState = ElementTransformState(element)
    }

    func continueManipulation(at point: CGPoint) {
        guard canEdit, let element, let start = manipulationStartState,
              manipulationType != .none else { return }
        let state = start.applying(manipulationType, from: manipulationStartPoint, to: point,
                                   current: ElementTransformState(element))
        switch manipulationType {
        case .move: element.position = state.position
        case .resize: element.size = state.size
        case .rotate: element.rotation = state.rotation
        case .none: break
        }
        publishPreview(element)
    }

    func endManipulation() {
        defer {
            manipulationType = .none
            manipulationStartState = nil
        }
        guard canEdit, let element, let start = manipulationStartState,
              let event = transformUseCase.commitEvent(from: start, to: element) else { return }
        editor?.applyEvent(event)
    }

    /// 保存・選択変更では、既に表示したプレビューを維持して開始値だけを破棄する。
    func cancelManipulation() {
        if !activeGestureKinds.isEmpty, let image = element as? ImageElement {
            imageEditingSessionUseCase.applyManipulationState(to: image, ended: true)
        }
        if let renderingProject {
            manipulationRenderingUseCase.finish(in: renderingProject)
        }
        renderingProject = nil
        manipulationType = .none
        manipulationStartState = nil
        discardGestureSession()
        clearGestureTransformState()
    }

    /// 選択枠が消えたときに呼ぶ。消えた選択枠からは終了通知が届かないため、進行中のジェスチャーを終える。
    /// 選択中の要素と別の要素を表示していた選択枠の通知（古い選択枠から遅れて届いたもの）は無視する。
    func endGesturesForRemovedOverlay(showing elementId: UUID) {
        guard element == nil || element?.id == elementId else { return }
        cancelManipulation()
    }

    func prepareImageRenderingForManipulation(in project: LogoProject?, highResolutionThreshold: CGFloat) -> Bool {
        guard canEdit else { return false }
        renderingProject = project
        return manipulationRenderingUseCase.prepare(in: project, highResolutionThreshold: highResolutionThreshold)
    }

    func finishImageRenderingAfterManipulation(in project: LogoProject?) {
        manipulationRenderingUseCase.finish(in: project)
        renderingProject = nil
    }

    func updatePosition(_ position: CGPoint) {
        guard canEdit, let element else { return }
        element.position = position
        publishPreview(element)
    }

    func updateSize(_ size: CGSize) {
        guard canEdit, let element else { return }
        element.size = size
        publishPreview(element)
    }

    func updateRotation(_ rotation: CGFloat) {
        guard canEdit, let element else { return }
        element.rotation = rotation
        publishPreview(element)
    }

    /// ジェスチャーの変形が未確定のあいだは受け付けない。2本目の指のタップでダブルタップが発火しても、操作中の要素を変えないため。
    func resetRotation() {
        guard canEdit, !hasPendingGestureTransform, let element,
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
        guard canEdit, let element else { return }
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
