//
//  ImageRoleUseCase.swift
//  GLogo
//
//  概要:
//  画像要素の役割切り替えとレイヤー整合性ルールを提供するユースケース。
//

import Foundation

/// 画像役割切り替えユースケース
struct ImageRoleUseCase {
    /// 画像要素の役割を切り替え、必要に応じて他要素の役割とZ順を調整する
    /// - Parameters:
    ///   - imageElement: 役割を切り替える対象画像要素
    ///   - project: 更新対象のプロジェクト
    /// - Returns: 役割切り替えを適用した場合は true
    func toggleRole(for imageElement: ImageElement, in project: inout LogoProject) -> Bool {
        let oldRole = imageElement.imageRole
        let newRole: ImageRole = (oldRole == .base) ? .overlay : .base

        if newRole == .base {
            for element in project.elements {
                guard let otherImageElement = element as? ImageElement,
                      otherImageElement.id != imageElement.id,
                      otherImageElement.imageRole == .base else {
                    continue
                }

                otherImageElement.imageRole = .overlay
                otherImageElement.zIndex = ElementPriority.image.rawValue + 10
            }
        }

        imageElement.imageRole = newRole

        if newRole == .base {
            imageElement.zIndex = ElementPriority.image.rawValue - 10
        } else {
            imageElement.zIndex = ElementPriority.image.rawValue + 10
        }

        project.elements.sort { $0.zIndex < $1.zIndex }
        return true
    }
}
