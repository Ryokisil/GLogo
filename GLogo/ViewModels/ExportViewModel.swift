//
//  ExportViewModel.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはロゴプロジェクトを画像としてエクスポートする機能を提供する
//  ビューモデルを定義しています。PNG/JPEGなどの出力形式、オリジナル/プリセット/カスタムの
//  サイズ設定、透明背景の有無、JPEG品質の調整など、エクスポート関連の設定を管理します。
//  また、エクスポート処理の実行や、生成された画像の共有機能も提供します。
//

import Foundation
import UIKit
import Combine

/// エクスポート形式
enum ExportFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpg = "JPEG"
    
    var id: String { self.rawValue }
    
    /// ファイル拡張子を取得
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpg: return "jpg"
        }
    }
    
    /// MIMEタイプを取得
    var mimeType: String {
        switch self {
        case .png: return "image/png"
        case .jpg: return "image/jpeg"
        }
    }
}

/// エクスポートサイズプリセット
enum ExportSizePreset: String, CaseIterable, Identifiable {
    case original = "オリジナル"
    case small = "小 (512px)"
    case medium = "中 (1024px)"
    case large = "大 (2048px)"
    case custom = "カスタム"
    
    var id: String { self.rawValue }
    
    /// プリセットに基づいたサイズを取得
    func getSize(for originalSize: CGSize) -> CGSize {
        switch self {
        case .original:
            return originalSize
        case .small:
            return scaleSizeKeepingAspectRatio(originalSize, targetLongerSide: 512)
        case .medium:
            return scaleSizeKeepingAspectRatio(originalSize, targetLongerSide: 1024)
        case .large:
            return scaleSizeKeepingAspectRatio(originalSize, targetLongerSide: 2048)
        case .custom:
            // カスタムサイズの場合は別途指定されるためそのまま返す
            return originalSize
        }
    }
    
    /// アスペクト比を維持したままサイズを変更
    private func scaleSizeKeepingAspectRatio(_ originalSize: CGSize, targetLongerSide: CGFloat) -> CGSize {
        let longerSide = max(originalSize.width, originalSize.height)
        let scale = targetLongerSide / longerSide
        
        return CGSize(
            width: round(originalSize.width * scale),
            height: round(originalSize.height * scale)
        )
    }
}

/// エクスポートビューモデル - エクスポート機能のロジックを管理
class ExportViewModel: ObservableObject {
    // MARK: - プロパティ
    
    /// エディタビューモデル参照
    private weak var editorViewModel: EditorViewModel?
    
    /// エクスポート形式
    @Published var exportFormat: ExportFormat = .png
    
    /// エクスポートサイズプリセット
    @Published var sizePreset: ExportSizePreset = .original
    
    /// カスタム幅
    @Published var customWidth: CGFloat = 1024
    
    /// カスタム高さ
    @Published var customHeight: CGFloat = 1024
    
    /// JPEG品質（JPEGの場合のみ使用）
    @Published var jpegQuality: Double = 0.9
    
    /// 透明背景（PNGの場合のみ使用）
    @Published var transparentBackground: Bool = true
    
    /// エクスポート中フラグ
    @Published private(set) var isExporting = false
    
    /// エクスポート完了フラグ
    @Published private(set) var isExportComplete = false
    
    /// エクスポートされた画像
    @Published private(set) var exportedImage: UIImage?
    
    /// エクスポートされたデータ
    private var exportedData: Data?
    
    // MARK: - イニシャライザ
    
    init(editorViewModel: EditorViewModel) {
        self.editorViewModel = editorViewModel
        
        // プロジェクトのキャンバスサイズを初期値に設定
        let canvasSize = editorViewModel.project.canvasSize
        customWidth = canvasSize.width
        customHeight = canvasSize.height
    }
    
    // MARK: - メソッド
    
    /// 現在の設定でエクスポートサイズを取得
    var exportSize: CGSize {
        if sizePreset == .custom {
            return CGSize(width: customWidth, height: customHeight)
        } else {
            let originalSize = editorViewModel?.project.canvasSize ?? CGSize(width: 1024, height: 1024)
            return sizePreset.getSize(for: originalSize)
        }
    }
    
    /// エクスポートを実行
    func performExport() {
        guard let editorViewModel = editorViewModel else { return }
        
        isExporting = true
        isExportComplete = false
        
        // 背景色の設定（透明背景が有効で、PNG形式の場合は透明に）
        let backgroundColor: UIColor? = exportFormat == .png && transparentBackground ? .clear : nil
        
        // エクスポート処理
        // サイズを適用してエクスポート
        if let image = editorViewModel.exportAsImage(size: exportSize, backgroundColor: backgroundColor) {
            exportedImage = image
            
            // 形式に応じてデータ変換
            switch exportFormat {
            case .png:
                exportedData = image.pngData()
            case .jpg:
                exportedData = image.jpegData(compressionQuality: jpegQuality)
            }
            
            isExportComplete = true
        }
        
        isExporting = false
    }
    
    /// エクスポートした画像を共有
    func shareExportedImage(completion: @escaping (Bool) -> Void) {
        guard let data = exportedData, let image = exportedImage else {
            completion(false)
            return
        }
        
        // ファイル名の作成
        let fileName = "\(editorViewModel?.project.name ?? "logo").\(exportFormat.fileExtension)"
        
        // 一時ファイルの作成
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempFileURL)
            
            // 共有アクティビティアイテムの作成
            let activityItems: [Any] = [image, tempFileURL]
            
            // UIActivityViewControllerを表示するためのコールバック
            completion(true)
            
            // URLをオブジェクトに保存（共有後に必要に応じて削除するため）
            // 注意: 実際の削除処理はUIActivityViewControllerの完了時に行う必要があります
        } catch {
            print("Error writing temp file: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    /// エクスポート設定をリセット
    func resetSettings() {
        guard let editorViewModel = editorViewModel else { return }
        
        exportFormat = .png
        sizePreset = .original
        
        let canvasSize = editorViewModel.project.canvasSize
        customWidth = canvasSize.width
        customHeight = canvasSize.height
        
        jpegQuality = 0.9
        transparentBackground = true
        
        isExportComplete = false
        exportedImage = nil
        exportedData = nil
    }
    
    /// アスペクト比を維持しながら幅を更新
    func updateWidthKeepingAspectRatio(_ width: CGFloat) {
        guard let editorViewModel = editorViewModel else { return }
        
        let originalSize = editorViewModel.project.canvasSize
        let aspectRatio = originalSize.height / originalSize.width
        
        customWidth = width
        customHeight = round(width * aspectRatio)
    }
    
    /// アスペクト比を維持しながら高さを更新
    func updateHeightKeepingAspectRatio(_ height: CGFloat) {
        guard let editorViewModel = editorViewModel else { return }
        
        let originalSize = editorViewModel.project.canvasSize
        let aspectRatio = originalSize.width / originalSize.height
        
        customHeight = height
        customWidth = round(height * aspectRatio)
    }
}
