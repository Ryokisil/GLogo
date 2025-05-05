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
import PhotosUI

/// 画像選択ソース
enum ImagePickerSource {
    case photoLibrary
    case camera
}

/// 簡易化された画像選択ビュー
struct ImagePickerView: View {
    /// 選択終了時のコールバック
    var onSelect: (UIImage?) -> Void
    
    /// ソースタイプ（デフォルトはフォトライブラリ）
    var source: ImagePickerSource = .photoLibrary
    
    /// 表示制御フラグ
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Group {
            if source == .photoLibrary {
                if #available(iOS 14, *) {
                    PhotoPicker(onSelect: { image in
                        print("PhotoPickerで画像が選択されました") // デバッグログ
                        onSelect(image)
                        // presentationMode.wrappedValue.dismiss() // この行はコメントアウトまたは削除
                    })
                } else {
                    LegacyImagePicker(source: .photoLibrary, onSelect: { image in
                        print("LegacyImagePickerで画像が選択されました") // デバッグログ
                        onSelect(image)
                        // presentationMode.wrappedValue.dismiss() // この行はコメントアウトまたは削除
                    })
                }
            } else {
                LegacyImagePicker(source: .camera, onSelect: { image in
                    print("カメラで画像が撮影されました") // デバッグログ
                    onSelect(image)
                    // presentationMode.wrappedValue.dismiss() // この行はコメントアウトまたは削除
                })
            }
        }
    }
}

/// iOS 14以降向けPHPickerViewControllerのラッパー
@available(iOS 14, *)
struct PhotoPicker: UIViewControllerRepresentable {
    var onSelect: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // 画像が選択されなかった場合
            guard let provider = results.first?.itemProvider else {
                parent.onSelect(nil)
                return
            }
            
            // 画像をロード
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    DispatchQueue.main.async {
                        self?.parent.onSelect(image as? UIImage)
                    }
                }
            } else {
                parent.onSelect(nil)
            }
        }
    }
}

/// 従来のUIImagePickerControllerのラッパー（iOS 13以前およびカメラ用）
struct LegacyImagePicker: UIViewControllerRepresentable {
    var source: ImagePickerSource
    var onSelect: (UIImage?) -> Void
    
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
                parent.onSelect(originalImage)
            } else {
                parent.onSelect(nil)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onSelect(nil)
        }
    }
}
