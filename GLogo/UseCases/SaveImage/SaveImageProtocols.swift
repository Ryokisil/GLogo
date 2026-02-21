//
//  SaveImageProtocols.swift
//  GLogo
//
//  概要:
//  保存処理の依存注入に使用するプロトコル群。
//  テスト時にモック実装へ差し替えるための抽象化レイヤー。
//

import Photos
import UIKit

/// 画像フィルタ適用・合成処理の抽象
protocol ImageProcessing {
    func applyFilters(to imageElement: ImageElement) -> UIImage?
    func makeCompositeImage(baseImage: UIImage, project: LogoProject) -> UIImage?
}

/// ベース画像要素の選択ロジックの抽象
protocol ImageSelecting {
    func selectBaseImageElement(from elements: [ImageElement]) -> ImageElement?
    func selectHighestResolutionImageElement(from elements: [ImageElement]) -> ImageElement?
}

/// 写真ライブラリ権限確認・書き込みの抽象
protocol PhotoLibraryWriting {
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus
    func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping (PHAuthorizationStatus) -> Void)
    func performSave(of image: UIImage, format: SaveImageFormat) async throws
}
