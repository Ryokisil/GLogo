// AI 加工の要求、処理中・エラー表示、マスク編集への遷移を管理する。

import Combine
import UIKit

/// AI 表示状態の唯一の所有者。推論と履歴確定は UseCase へ委譲する。
@MainActor
final class AIToolsViewModel: ObservableObject {
    @Published private(set) var isProcessingAI = false
    @Published private(set) var isProcessingUpscale = false
    @Published private(set) var lastUpscaleErrorMessage: String?
    @Published private(set) var lastBackgroundRemovalErrorMessage: String?
    @Published private(set) var lastBackgroundBlurErrorMessage: String?
    @Published private(set) var backgroundBlurMaskEditTarget: ImageElement?
    @Published var isNavigatingToBackgroundBlurMaskEdit = false

    private let edits: any AIImageEditApplying
    private let backgroundRemovalUseCase: any BackgroundRemovalProcessing
    private let imageUpscaleUseCase: ImageUpscaleUseCase
    private var selectionObservation: AnyCancellable?
    private var changeObservation: AnyCancellable?
    private var aiTask: Task<Void, Never>?
    private var upscaleTask: Task<Void, Never>?
    private var aiRequest: (ImageElement, ImageEditToken)?
    private var upscaleRequest: (ImageElement, ImageEditToken)?
    private var selectedElementID: UUID?
    private var selectionRevision: UInt = 0

    var isRealESRGANAvailable: Bool { imageUpscaleUseCase.isRealESRGANAvailable }

    /// selection は現在値と選択変更を MainActor 上で同期通知する。
    /// changes は Editor の変更前通知。省略時も結果の照合は行うが、選択通知のない編集での中止要求は送らない。
    /// 加工結果の適用先は edits が非所有で参照し、親の寿命を延長しない。
    init(
        edits: any AIImageEditApplying,
        backgroundRemovalUseCase: any BackgroundRemovalProcessing,
        imageUpscaleUseCase: ImageUpscaleUseCase,
        selection: AnyPublisher<LogoElement?, Never>,
        changes: AnyPublisher<Void, Never> = Empty().eraseToAnyPublisher()
    ) {
        self.edits = edits
        self.backgroundRemovalUseCase = backgroundRemovalUseCase
        self.imageUpscaleUseCase = imageUpscaleUseCase
        selectionObservation = selection.sink { [weak self] element in
            self?.cancelInvalidRequests()
            guard let self, self.selectedElementID != element?.id else { return }
            self.selectedElementID = element?.id
            self.selectionRevision &+= 1
            self.clearUpscaleError()
            self.clearBackgroundRemovalError()
            self.clearBackgroundBlurError()
        }
        changeObservation = changes.sink { [weak self] in
            guard let self, self.aiRequest != nil || self.upscaleRequest != nil else { return }
            // objectWillChange は代入前なので、同じ MainActor の更新が終わってから照合する。
            Task { @MainActor [weak self] in self?.cancelInvalidRequests() }
        }
    }

    deinit {
        aiTask?.cancel()
        upscaleTask?.cancel()
    }

    /// 選択変更だけでは中止せず、所属・画像属性・履歴が変わった要求だけを止める。
    private func cancelInvalidRequests() {
        if let (image, token) = aiRequest, !edits.isImageEditCurrent(token, for: image) {
            aiTask?.cancel()
        }
        if let (image, token) = upscaleRequest, !edits.isImageEditCurrent(token, for: image) {
            upscaleTask?.cancel()
        }
    }

    func requestAIBackgroundRemoval(for imageElement: ImageElement) {
        guard !isProcessingAI, let token = edits.imageEditToken(for: imageElement) else { return }
        let originalImage = imageElement.originalImage
        let errorSelectionRevision = selectionRevision
        lastBackgroundRemovalErrorMessage = nil
        aiRequest = (imageElement, token)
        isProcessingAI = true

        // await をまたいで self を保持しない。画面所有者の解放後の結果は適用しない。
        aiTask = Task { [weak self, backgroundRemovalUseCase] in
            defer {
                self?.aiRequest = nil
                self?.aiTask = nil
                self?.isProcessingAI = false
            }
            guard !Task.isCancelled, self?.edits.isImageEditCurrent(token, for: imageElement) == true else { return }
            guard let originalImage else {
                if self?.shouldPresentFailure(token, for: imageElement, selectionRevision: errorSelectionRevision) == true {
                    self?.lastBackgroundRemovalErrorMessage = String(localized: "aiTools.sourceImageUnavailable")
                }
                return
            }
            do {
                let result = try await backgroundRemovalUseCase.removeBackground(from: originalImage)
                guard !Task.isCancelled, self?.edits.isImageEditCurrent(token, for: imageElement) == true else { return }
                self?.edits.applyManualBackgroundRemovalResult(result, to: imageElement)
            } catch {
                guard self?.shouldPresentFailure(token, for: imageElement, selectionRevision: errorSelectionRevision) == true else { return }
                self?.lastBackgroundRemovalErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func requestAIBackgroundBlur(for imageElement: ImageElement) {
        guard !isProcessingAI, let token = edits.imageEditToken(for: imageElement) else { return }
        let originalImage = imageElement.originalImage
        let errorSelectionRevision = selectionRevision
        lastBackgroundBlurErrorMessage = nil
        aiRequest = (imageElement, token)
        isProcessingAI = true

        aiTask = Task { [weak self, backgroundRemovalUseCase] in
            defer {
                self?.aiRequest = nil
                self?.aiTask = nil
                self?.isProcessingAI = false
            }
            guard !Task.isCancelled, self?.edits.isImageEditCurrent(token, for: imageElement) == true else { return }
            guard let originalImage else {
                if self?.shouldPresentFailure(token, for: imageElement, selectionRevision: errorSelectionRevision) == true {
                    self?.lastBackgroundBlurErrorMessage = String(localized: "aiTools.sourceImageUnavailable")
                }
                return
            }
            do {
                let mask = try await backgroundRemovalUseCase.generateMask(from: originalImage)
                guard !Task.isCancelled, let self, self.edits.isImageEditCurrent(token, for: imageElement) else { return }
                if !self.edits.applyAIBackgroundBlurMask(mask, to: imageElement) {
                    if self.shouldPresentFailure(token, for: imageElement, selectionRevision: errorSelectionRevision) {
                        self.lastBackgroundBlurErrorMessage = String(localized: "aiTools.aiMaskGeneration.failed")
                    }
                }
            } catch {
                guard self?.shouldPresentFailure(token, for: imageElement, selectionRevision: errorSelectionRevision) == true else { return }
                self?.lastBackgroundBlurErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func requestImageUpscale(
        for imageElement: ImageElement,
        method: ImageUpscaleMethod = .realESRGAN,
        scaleFactor: ImageUpscaleScaleFactor = .x2,
        appliesSharpening: Bool = true
    ) {
        guard !isProcessingUpscale,
              let token = edits.imageEditToken(for: imageElement),
              let originalImage = imageElement.originalImage,
              !imageElement.hasAppliedUpscale else { return }
        let errorSelectionRevision = selectionRevision
        lastUpscaleErrorMessage = nil
        upscaleRequest = (imageElement, token)
        isProcessingUpscale = true
        let request = ImageUpscaleRequest(
            sourceImage: originalImage, method: method,
            scaleFactor: scaleFactor, appliesSharpening: appliesSharpening
        )
        upscaleTask = Task { [weak self, imageUpscaleUseCase] in
            defer {
                self?.upscaleRequest = nil
                self?.upscaleTask = nil
                self?.isProcessingUpscale = false
            }
            guard !Task.isCancelled, self?.edits.isImageEditCurrent(token, for: imageElement) == true else { return }
            do {
                let result = try await imageUpscaleUseCase.upscale(request)
                guard !Task.isCancelled, self?.edits.isImageEditCurrent(token, for: imageElement) == true else { return }
                self?.edits.applyUpscaledImageResult(result.image, to: imageElement)
            } catch {
                guard self?.shouldPresentFailure(token, for: imageElement, selectionRevision: errorSelectionRevision) == true else { return }
                self?.lastUpscaleErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    func clearUpscaleError() { lastUpscaleErrorMessage = nil }
    func clearBackgroundRemovalError() { lastBackgroundRemovalErrorMessage = nil }
    func clearBackgroundBlurError() { lastBackgroundBlurErrorMessage = nil }

    /// 選択を離れて戻った場合も、以前の画面に属するエラーを復活させない。
    private func shouldPresentFailure(_ token: ImageEditToken, for element: ImageElement, selectionRevision: UInt) -> Bool {
        !Task.isCancelled && self.selectionRevision == selectionRevision && selectedElementID == element.id
            && edits.isImageEditCurrent(token, for: element)
    }

    func requestBackgroundBlurMaskEdit(for imageElement: ImageElement) {
        backgroundBlurMaskEditTarget = imageElement
        isNavigatingToBackgroundBlurMaskEdit = true
    }

    func applyManualBackgroundRemovalResult(_ image: UIImage, to element: ImageElement) {
        edits.applyManualBackgroundRemovalResult(image, to: element)
    }

    func applyBackgroundBlurMaskResult(_ data: Data?, to element: ImageElement) {
        edits.applyBackgroundBlurMaskResult(data, to: element)
    }

    func removeBackgroundBlurMask(from element: ImageElement) {
        edits.removeBackgroundBlurMask(from: element)
    }
}
