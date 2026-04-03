//
//  ImagePickerView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはフォトライブラリやカメラから画像を選択するためのビューを実装しています。
//  UIImagePickerControllerとPHPickerViewControllerをSwiftUIに統合するブリッジとして機能します。
//  ユーザーが選択した画像を取得し、コールバックを通じてアプリの他の部分に提供します。
//  シンプルな方法で画像を選択し、後続の画像編集フローにスムーズに連携します。
//

import SwiftUI
import UIKit
import Photos
import PhotosUI

/// 画像選択ソース
enum ImagePickerSource {
    case photoLibrary
    case camera
}

/// 選択された画像の情報を保持する構造体
struct SelectedImageInfo {
    let image: UIImage?
    let assetIdentifier: String?
    let url: URL?
    let phAsset: PHAsset?
    let metadata: ImageMetadata?
    
    init(image: UIImage?, assetIdentifier: String? = nil, url: URL? = nil, phAsset: PHAsset? = nil, metadata: ImageMetadata? = nil) {
        self.image = image
        self.assetIdentifier = assetIdentifier
        self.url = url
        self.phAsset = phAsset
        self.metadata = metadata
    }
}

/// 簡易化された画像選択ビュー
struct ImagePickerView: View {
    /// 選択終了時のコールバック
    var onSelect: (SelectedImageInfo) -> Void
    
    /// ソースタイプ（デフォルトはフォトライブラリ）
    var source: ImagePickerSource = .photoLibrary
    
    /// 表示制御フラグ
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Group {
            if source == .photoLibrary {
                if #available(iOS 14, *) {
                    PhotoPicker(onSelect: { imageInfo in
                        onSelect(imageInfo)
                    })
                } else {
                    LegacyImagePicker(source: .photoLibrary, onSelect: { imageInfo in
                        onSelect(imageInfo)
                    })
                }
            } else {
                LegacyImagePicker(source: .camera, onSelect: { imageInfo in
                    onSelect(imageInfo)
                })
            }
        }
    }
}

/// iOS 14以降向けPHPickerViewControllerのラッパー
@available(iOS 14, *)
struct PhotoPicker: UIViewControllerRepresentable {
    var onSelect: (SelectedImageInfo) -> Void
    
    /// ソースタイプ（デフォルトはフォトライブラリ）
    var source: ImagePickerSource = .photoLibrary
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.filter = .images
        config.selectionLimit = 1
        
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        /// `UIImage` をスレッド境界で受け渡すための軽量ラッパー
        private struct SendableUIImageBox: @unchecked Sendable {
            let value: UIImage?
        }

        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            var assetIdentifier: String?
            if #available(iOS 15.0, *) {
                if let identifier = results.first?.assetIdentifier {
                    assetIdentifier = identifier
                }
            }

            handlePickedItemProvider(
                results.first?.itemProvider,
                assetIdentifier: assetIdentifier,
                picker: picker
            )
        }

        /// itemProvider から画像選択結果を処理する
        /// - Parameters:
        ///   - provider: 選択結果の `NSItemProvider`
        ///   - assetIdentifier: PHAsset のローカル識別子
        ///   - picker: 呼び出し元 picker
        /// - Returns: なし
        func handlePickedItemProvider(
            _ provider: NSItemProvider?,
            assetIdentifier: String?,
            picker: PHPickerViewController
        ) {
            // 選択がキャンセルされた場合
            guard let provider else {
                parent.onSelect(SelectedImageInfo(image: nil))
                picker.dismiss(animated: true)
                return
            }

            let selectedAsset: PHAsset? = {
                guard let identifier = assetIdentifier else { return nil }
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                return assets.firstObject
            }()
            
            guard provider.canLoadObject(ofClass: UIImage.self) else {
                parent.onSelect(
                    SelectedImageInfo(
                        image: nil,
                        assetIdentifier: assetIdentifier,
                        phAsset: selectedAsset
                    )
                )
                picker.dismiss(animated: true)
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                let sendableImage = SendableUIImageBox(value: image as? UIImage)
                DispatchQueue.main.async {
                    guard let image = sendableImage.value else {
                        self?.parent.onSelect(
                            SelectedImageInfo(
                                image: nil,
                                assetIdentifier: assetIdentifier,
                                phAsset: selectedAsset
                            )
                        )
                        picker.dismiss(animated: true)
                        return
                    }

                    self?.parent.onSelect(
                        SelectedImageInfo(
                            image: image,
                            assetIdentifier: assetIdentifier,
                            phAsset: selectedAsset
                        )
                    )
                    picker.dismiss(animated: true)
                }
            }
        }
    }
}

/// 従来のUIImagePickerControllerのラッパー
struct LegacyImagePicker: UIViewControllerRepresentable {
    var source: ImagePickerSource
    var onSelect: (SelectedImageInfo) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false // 編集機能を無効化（独自のクロップ画面を使用するため）
        
        switch source {
        case .photoLibrary:
            picker.sourceType = .photoLibrary
        case .camera:
            picker.sourceType = .camera
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: LegacyImagePicker
        
        init(_ parent: LegacyImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // 編集された画像よりもオリジナルの画像を優先
            if let originalImage = info[.originalImage] as? UIImage {
                parent.onSelect(SelectedImageInfo(image: originalImage))
            } else {
                parent.onSelect(SelectedImageInfo(image: nil))
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onSelect(SelectedImageInfo(image: nil))
        }
    }
}
