//
//  CropModels.swift
//
//  概要:
//  クロップ機能で使用するモデル
//

import Foundation
import UIKit

enum CropHandleType: CaseIterable {
    case topLeft, topCenter, topRight
    case middleLeft, middleRight
    case bottomLeft, bottomCenter, bottomRight
}

extension CGRect {
    func equalTo(_ other: CGRect) -> Bool {
        let tolerance: CGFloat = 0.01
        return abs(self.minX - other.minX) < tolerance &&
        abs(self.minY - other.minY) < tolerance &&
        abs(self.width - other.width) < tolerance &&
        abs(self.height - other.height) < tolerance
    }
}

extension UIImage {
    func cropToRect(_ rect: CGRect) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        _ = self.size.width / self.scale
        _ = self.size.height / self.scale
        
        let scaledRect = CGRect(
            x: rect.origin.x * self.scale,
            y: rect.origin.y * self.scale,
            width: rect.size.width * self.scale,
            height: rect.size.height * self.scale
        )
        
        guard let croppedCGImage = cgImage.cropping(to: scaledRect) else { return nil }
        return UIImage(cgImage: croppedCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
}
