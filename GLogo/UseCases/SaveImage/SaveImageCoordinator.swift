//
// 概要：保存フローのハブ。要素構成から保存モードを自動判定し、選定 → フィルター/合成 → 保存を呼び出す。
//

import UIKit
import OSLog

struct SaveImageCoordinator: Sendable {
    private static let logger = Logger(subsystem: "com.silvia.GLogo", category: "Save")
    private let policy: SaveImagePolicy
    private let selectionService: any ImageSelecting
    private let processingService: any ImageProcessing
    private let writer: any PhotoLibraryWriting

    /// detached タスクへ安全に渡す参照ラッパー
    private final class DetachedProjectBox: @unchecked Sendable {
        let project: LogoProject

        init(project: LogoProject) {
            self.project = project
        }
    }

    init(
        policy: SaveImagePolicy = SaveImagePolicy(),
        selectionService: any ImageSelecting = ImageSelectionService(),
        processingService: any ImageProcessing = ImageProcessingService(),
        writer: any PhotoLibraryWriting = PhotoLibraryWriter()
    ) {
        self.policy = policy
        self.selectionService = selectionService
        self.processingService = processingService
        self.writer = writer
    }

    /// 保存モードを自動判定して通常/合成どちらかを保存する入口
    @MainActor
    func save(project: LogoProject, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let mode = policy.resolveMode(elements: project.elements)
        let projectBox = DetachedProjectBox(project: project)

        authorizeIfNeeded { authorized in
            guard authorized else {
                completion(false)
                return
            }

            performSave(projectBox: projectBox, mode: mode, completion: completion)
        }
    }

    /// 合成保存を強制実行する入口（互換用）
    @MainActor
    func saveComposite(project: LogoProject, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let projectBox = DetachedProjectBox(project: project)

        authorizeIfNeeded { authorized in
            guard authorized else {
                completion(false)
                return
            }

            performSave(projectBox: projectBox, mode: .composite, completion: completion)
        }
    }

    /// 写真ライブラリ権限を確認（未決定ならリクエスト）
    private func authorizeIfNeeded(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let authStatus = writer.authorizationStatus(for: .addOnly)

        switch authStatus {
        case .authorized, .limited:
            Task { @MainActor in
                completion(true)
            }
        case .notDetermined:
            writer.requestAuthorization(for: .addOnly) { status in
                Task { @MainActor in
                    completion(status == .authorized || status == .limited)
                }
            }
        default:
            Task { @MainActor in
                completion(false)
            }
        }
    }

    /// モード別に保存フローを実行（要素選定 → フィルター/合成 → 保存）
    /// バックグラウンドスレッドで実行し、メインスレッドのブロックを防止する
    private func performSave(
        projectBox: DetachedProjectBox,
        mode: SaveImageMode,
        completion: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        Task.detached(priority: .userInitiated) {
            let project = projectBox.project
            let imageElements = project.elements.compactMap { $0 as? ImageElement }
            if imageElements.isEmpty {
                await completion(false)
                return
            }

            switch mode {
            case .failure:
                await completion(false)
            case .individual:
                let targetImageElement = selectionService.selectHighestResolutionImageElement(from: imageElements)
                guard let imageElement = targetImageElement,
                      let processedImage = processingService.applyFilters(to: imageElement) else {
                    await completion(false)
                    return
                }

                do {
                    let format = SaveImageCoordinator.resolveFormat(for: processedImage, mode: mode)
                    try await writer.performSave(of: processedImage, format: format)
                    await completion(true)
                } catch {
                    await completion(false)
                }
            case .composite:
                let baseImageElement = selectionService.selectBaseImageElement(from: imageElements)
                guard let selectedBaseImageElement = baseImageElement,
                      let baseImage = processingService.applyFilters(to: selectedBaseImageElement) else {
                    await completion(false)
                    return
                }

                guard let finalImage = processingService.makeCompositeImage(
                    baseImage: baseImage,
                    project: project
                ) else {
                    Self.logger.warning("合成保存に失敗: makeCompositeImage が nil を返却")
                    await completion(false)
                    return
                }

                do {
                    let format = SaveImageCoordinator.resolveFormat(for: finalImage, mode: mode)
                    try await writer.performSave(of: finalImage, format: format)
                    await completion(true)
                } catch {
                    await completion(false)
                }
            }
        }
    }

    private static func resolveFormat(for image: UIImage, mode: SaveImageMode) -> SaveImageFormat {
        switch mode {
        case .individual:
            return imageHasAlpha(image) ? .png : .heic
        case .composite:
            return .heic
        case .failure:
            return .heic
        }
    }

    private static func imageHasAlpha(_ image: UIImage) -> Bool {
        let cgImage = image.cgImage ?? makeCGImage(from: image)
        guard let alphaInfo = cgImage?.alphaInfo else { return false }
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            return true
        }
    }

    private static func makeCGImage(from image: UIImage) -> CGImage? {
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
