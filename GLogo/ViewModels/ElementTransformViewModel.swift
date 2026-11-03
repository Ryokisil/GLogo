// 座標操作と同時ジェスチャーの開始値・プレビュー・終了処理を管理する。

import Combine
import UIKit

/// 変形状態を親子で共有し、選択 ID と保存ロックの境界で開始値を破棄する。
@MainActor
final class ElementTransformViewModel: ObservableObject {
    @Published private(set) var element: LogoElement?
    @Published private(set) var manipulationType: ElementManipulationType = .none

    private weak var editor: (any ElementTransformApplying)?
    private var selectionObservation: AnyCancellable?
    private var manipulationStartPoint: CGPoint = .zero
    private var manipulationStartState: ElementTransformState?
    private var gestureBasePosition: CGPoint?
    private var gestureBaseSize: CGSize?
    private var gestureBaseRotation: CGFloat?
    private var activeGestureKinds = Set<ElementGestureTransformKind>()
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
        clearGestureTransformState()
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

    func resetRotation() {
        guard canEdit, let element, let event = transformUseCase.resetRotationEvent(for: element) else { return }
        editor?.applyEvent(event)
    }

    private func publishPreview(_ element: LogoElement) {
        self.element = element
        editor?.updateSelectedElement(element)
    }

    /// ジェスチャーによる変形（移動・拡大縮小・回転）
    func applyGestureTransform(
        kind: ElementGestureTransformKind,
        translation: CGSize?,
        scale: CGFloat?,
        rotation: CGFloat?,
        ended: Bool
    ) {
        guard canEdit, let element else { return }

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
        if !ended && !hasMeaningfulInput { return }

        // 終了イベントだけ飛んできたケースは無視（未開始ジェスチャーの終了）
        if ended, !hasGestureBase(for: kind) {
            return
        }

        if let imageElement = element as? ImageElement {
            if ended {
                activeGestureKinds.remove(kind)
                if activeGestureKinds.isEmpty {
                    imageEditingSessionUseCase.applyManipulationState(to: imageElement, ended: true)
                }
            } else {
                activeGestureKinds.insert(kind)
                imageEditingSessionUseCase.applyManipulationState(to: imageElement, ended: false)
            }
        } else if ended {
            activeGestureKinds.remove(kind)
        } else {
            activeGestureKinds.insert(kind)
        }

        if ended {
            clearGestureBase(for: kind)
            if activeGestureKinds.isEmpty {
                editor?.markProjectModified()
            }
            return
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


    /// ジェスチャー変形の保持状態を初期化
    private func clearGestureTransformState() {
        gestureBasePosition = nil
        gestureBaseSize = nil
        gestureBaseRotation = nil
        activeGestureKinds.removeAll()
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

    /// 指定ジェスチャーの基準値が開始済みかを返す
    private func hasGestureBase(for kind: ElementGestureTransformKind) -> Bool {
        switch kind {
        case .move:
            return gestureBasePosition != nil
        case .magnify:
            return gestureBaseSize != nil
        case .rotate:
            return gestureBaseRotation != nil
        }
    }
}
