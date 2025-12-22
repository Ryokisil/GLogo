//
// 概要：保存フローのハブ。要素構成から保存モードを自動判定し、選定 → フィルター/合成 → 保存を呼び出す。
//

import UIKit

struct SaveImageCoordinator {
    private let policy: SaveImagePolicy
    private let selectionService: ImageSelectionService
    private let processingService: ImageProcessingService
    private let writer: PhotoLibraryWriter

    init(
        policy: SaveImagePolicy = SaveImagePolicy(),
        selectionService: ImageSelectionService = ImageSelectionService(),
        processingService: ImageProcessingService = ImageProcessingService(),
        writer: PhotoLibraryWriter = PhotoLibraryWriter()
    ) {
        self.policy = policy
        self.selectionService = selectionService
        self.processingService = processingService
        self.writer = writer
    }

    /// 保存モードを自動判定して通常/合成どちらかを保存する入口
    func save(project: LogoProject, completion: @escaping (Bool) -> Void) {
        authorizeIfNeeded { authorized in
            guard authorized else {
                completion(false)
                return
            }

            let mode = policy.resolveMode(elements: project.elements)
            performSave(project: project, mode: mode, completion: completion)
        }
    }

    /// 合成保存を強制実行する入口（互換用）
    func saveComposite(project: LogoProject, completion: @escaping (Bool) -> Void) {
        authorizeIfNeeded { authorized in
            guard authorized else {
                completion(false)
                return
            }

            performSave(project: project, mode: .composite, completion: completion)
        }
    }

    /// 写真ライブラリ権限を確認（未決定ならリクエスト）
    private func authorizeIfNeeded(completion: @escaping (Bool) -> Void) {
        let authStatus = writer.authorizationStatus(for: .addOnly)

        switch authStatus {
        case .authorized, .limited:
            completion(true)
        case .notDetermined:
            writer.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    completion(status == .authorized || status == .limited)
                }
            }
        default:
            completion(false)
        }
    }

    /// モード別に保存フローを実行（要素選定 → フィルター/合成 → 保存）
    private func performSave(project: LogoProject, mode: SaveImageMode, completion: @escaping (Bool) -> Void) {
        Task.detached(priority: .userInitiated) {
            let imageElements = project.elements.compactMap { $0 as? ImageElement }
            if imageElements.isEmpty {
                await MainActor.run { completion(false) }
                return
            }

            switch mode {
            case .failure:
                await MainActor.run { completion(false) }
            case .individual:
                let targetImageElement = selectionService.selectHighestResolutionImageElement(from: imageElements)
                guard let imageElement = targetImageElement,
                      let processedImage = processingService.applyFilters(to: imageElement) else {
                    await MainActor.run { completion(false) }
                    return
                }

                do {
                    let format = resolveFormat(for: processedImage, mode: mode)
                    try await writer.performSave(of: processedImage, format: format)
                    await MainActor.run { completion(true) }
                } catch {
                    await MainActor.run { completion(false) }
                }
            case .composite:
                let baseImageElement = selectionService.selectBaseImageElement(from: imageElements)
                guard let selectedBaseImageElement = baseImageElement,
                      let baseImage = processingService.applyFilters(to: selectedBaseImageElement) else {
                    await MainActor.run { completion(false) }
                    return
                }

                let overlayElements = project.elements.filter { element in
                    element.id != selectedBaseImageElement.id && element.isVisible
                }

                let finalImage = processingService.makeCompositeImage(
                    baseImage: baseImage,
                    overlayElements: overlayElements,
                    project: project
                ) ?? baseImage

                do {
                    let format = resolveFormat(for: finalImage, mode: mode)
                    try await writer.performSave(of: finalImage, format: format)
                    await MainActor.run { completion(true) }
                } catch {
                    await MainActor.run { completion(false) }
                }
            }
        }
    }

    private func resolveFormat(for image: UIImage, mode: SaveImageMode) -> SaveImageFormat {
        switch mode {
        case .individual:
            return imageHasAlpha(image) ? .png : .heic
        case .composite:
            return .heic
        case .failure:
            return .heic
        }
    }

    private func imageHasAlpha(_ image: UIImage) -> Bool {
        let cgImage = image.cgImage ?? makeCGImage(from: image)
        guard let alphaInfo = cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            return true
        }
    }

    private func makeCGImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cgImage = image.cgImage {
            return cgImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }
}
