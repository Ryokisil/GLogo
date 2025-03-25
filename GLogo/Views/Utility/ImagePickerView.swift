//
//  ImagePickerView.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはフォトライブラリやカメラから画像を選択するためのビューを実装しています。
//  UIImagePickerControllerをSwiftUIに統合するためのブリッジとして機能します。
//  ユーザーが選択した画像を取得し、コールバックを通じてアプリの他の部分に提供します。
//  主にロゴの背景や画像要素を追加する際に使用されます。
//

import SwiftUI
import UIKit
import PhotosUI

/// 画像選択ビュー - UIImagePickerControllerのSwiftUIラッパー
struct ImagePickerView: UIViewControllerRepresentable {
    /// 画像選択後のコールバック
    var onImageSelected: (UIImage?) -> Void
    
    /// ソースタイプ（カメラまたはフォトライブラリ）
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    /// ビューの作成
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true
        return picker
    }
    
    /// ビューの更新（変更なし）
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    /// コーディネーターの作成
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// コーディネータークラス - 選択処理を仲介
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        /// 画像選択完了時の処理
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // 編集された画像を取得
            if let editedImage = info[.editedImage] as? UIImage {
                parent.onImageSelected(editedImage)
            }
            // 編集されていない場合はオリジナル画像を取得
            else if let originalImage = info[.originalImage] as? UIImage {
                parent.onImageSelected(originalImage)
            } else {
                parent.onImageSelected(nil)
            }
            
            // ピッカーを閉じる
            picker.dismiss(animated: true)
        }
        
        /// キャンセル時の処理
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImageSelected(nil)
            picker.dismiss(animated: true)
        }
    }
}

/// PHPickerを使用した現代的な画像選択ビュー（iOS 14以降用）
@available(iOS 14, *)
struct PHImagePickerView: UIViewControllerRepresentable {
    /// 画像選択後のコールバック
    var onImageSelected: (UIImage?) -> Void
    
    /// 複数選択を許可するか
    var allowsMultipleSelection = false
    
    /// フィルタ（画像のみなど）
    var filter: PHPickerFilter = .images
    
    /// ビューの作成
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = filter
        configuration.selectionLimit = allowsMultipleSelection ? 0 : 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    /// ビューの更新（変更なし）
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    /// コーディネーターの作成
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// コーディネータークラス - 選択処理を仲介
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PHImagePickerView
        
        init(_ parent: PHImagePickerView) {
            self.parent = parent
        }
        
        /// 画像選択完了時の処理
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            // 選択結果がない場合
            guard let result = results.first else {
                parent.onImageSelected(nil)
                return
            }
            
            // 画像のロード
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let error = error {
                    print("画像の読み込みに失敗しました: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.parent.onImageSelected(nil)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self?.parent.onImageSelected(object as? UIImage)
                }
            }
        }
    }
}

/// カメラアクセス状態の確認と要求
struct CameraAccessView: View {
    /// カメラへのアクセス許可状態
    @State private var cameraAccessGranted = false
    
    /// カメラビューの表示フラグ
    @State private var showingCameraView = false
    
    /// 画像選択後のコールバック
    var onImageSelected: (UIImage?) -> Void
    
    var body: some View {
        VStack {
            if cameraAccessGranted {
                // カメラアクセスが許可されている場合
                if showingCameraView {
                    ImagePickerView(onImageSelected: onImageSelected, sourceType: .camera)
                }
            } else {
                // カメラアクセスが許可されていない場合
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("カメラへのアクセスが必要です")
                        .font(.headline)
                    
                    Text("「設定」からアプリにカメラへのアクセスを許可してください。")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    Button("設定を開く") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .onAppear {
            checkCameraPermission()
        }
    }
    
    /// カメラへのアクセス許可を確認
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // すでに許可されている場合
            cameraAccessGranted = true
            showingCameraView = true
            
        case .notDetermined:
            // まだ決定されていない場合、許可を要求
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraAccessGranted = granted
                    showingCameraView = granted
                }
            }
            
        default:
            // 拒否または制限されている場合
            cameraAccessGranted = false
            showingCameraView = false
        }
    }
}

/// 画像ソース選択ビュー - カメラ/ライブラリ選択UI
struct ImageSourcePickerView: View {
    /// ビューの表示フラグ
    @Binding var isPresented: Bool
    
    /// 画像選択後のコールバック
    var onImageSelected: (UIImage?) -> Void
    
    /// フォトピッカー表示フラグ
    @State private var showingPhotoPicker = false
    
    /// カメラ表示フラグ
    @State private var showingCamera = false
    
    var body: some View {
        NavigationView {
            List {
                // カメラオプション
                Button(action: {
                    showingCamera = true
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: "camera.fill")
                            .frame(width: 30, height: 30)
                            .foregroundColor(.blue)
                        Text("カメラで撮影")
                    }
                }
                
                // フォトライブラリオプション
                Button(action: {
                    showingPhotoPicker = true
                    isPresented = false
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                            .frame(width: 30, height: 30)
                            .foregroundColor(.blue)
                        Text("フォトライブラリから選択")
                    }
                }
            }
            .navigationTitle("画像を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            if #available(iOS 14, *) {
                PHImagePickerView(onImageSelected: { image in
                    onImageSelected(image)
                })
            } else {
                ImagePickerView(onImageSelected: { image in
                    onImageSelected(image)
                })
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraAccessView(onImageSelected: { image in
                onImageSelected(image)
            })
        }
    }
}

/// プレビュー
struct ImagePickerView_Previews: PreviewProvider {
    static var previews: some View {
        Text("画像選択デモ")
            .sheet(isPresented: .constant(true)) {
                if #available(iOS 14, *) {
                    PHImagePickerView { _ in }
                } else {
                    ImagePickerView { _ in }
                }
            }
    }
}
