////
////  SceneDelegate.swift
////  GameLogoMaker
////
////  概要:
////  このファイルはiPadOS環境でのシーンライフサイクルを管理目的だけどiPad版としてリリースするかはまだ未定
////
//
//import UIKit
//import SwiftUI
//
//class SceneDelegate: UIResponder, UIWindowSceneDelegate {
//    
//    var window: UIWindow?
//    
//    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
//        // シーンが作成されたときに呼ばれる
//        
//        // SwiftUIビューを使用してウィンドウのコンテンツを設定
//        if let windowScene = scene as? UIWindowScene {
//            let window = UIWindow(windowScene: windowScene)
//            
//            // メインエディタビューモデルを作成
//            let editorViewModel = EditorViewModel()
//            
//            // ウィンドウのルートビューを設定
//            window.rootViewController = UIHostingController(
//                rootView: EditorView(viewModel: editorViewModel)
//            )
//            
//            self.window = window
//            window.makeKeyAndVisible()
//            
//            // ドキュメントの読み込み処理（URLがある場合）
//            if let urlContext = connectionOptions.urlContexts.first {
//                handleIncomingURL(urlContext.url)
//            }
//        }
//    }
//    
//    func sceneDidDisconnect(_ scene: UIScene) {
//        // シーンが切断されたときに呼ばれる（iPadでマルチタスキングからシーンが閉じられた場合など）
//        // このシーンに関連するリソースを解放するのに適しています
//    }
//    
//    func sceneDidBecomeActive(_ scene: UIScene) {
//        // シーンがアクティブになったときに呼ばれる（アプリがフォアグラウンドに来たときなど）
//        // このタイミングで中断されていたタスクを再開するのに適しています
//        
//        // アクティビティモニタリングの再開
//        resumeActivityMonitoring()
//    }
//    
//    func sceneWillResignActive(_ scene: UIScene) {
//        // シーンがアクティブでなくなるときに呼ばれる（ユーザーが通知センターを開いたときなど）
//        // このタイミングで一時的に中断すべきタスクを保存するのに適しています
//    }
//    
//    func sceneWillEnterForeground(_ scene: UIScene) {
//        // シーンがフォアグラウンドに入るときに呼ばれる（アプリが背景から復帰するときなど）
//        // このタイミングでユーザーインターフェースを更新するのに適しています
//        
//        // 自動保存タイマーの再開
//        resumeAutosaveTimer()
//        
//        // バックグラウンド実行中に変更された可能性のあるデータを更新
//        refreshDataIfNeeded()
//    }
//    
//    func sceneDidEnterBackground(_ scene: UIScene) {
//        // シーンがバックグラウンドに入るときに呼ばれる（ユーザーがアプリを閉じたときなど）
//        // このタイミングで変更を保存し、リソースを解放するのに適しています
//        
//        // 現在のプロジェクトの状態を保存
//        saveCurrentProjectState()
//        
//        // 自動保存タイマーの一時停止
//        pauseAutosaveTimer()
//    }
//    
//    // MARK: - URL処理
//    
//    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
//        // URLからアプリが開かれた場合に呼ばれる
//        if let url = URLContexts.first?.url {
//            handleIncomingURL(url)
//        }
//    }
//    
//    /// 受信したURLを処理
//    private func handleIncomingURL(_ url: URL) {
//        // ファイルの種類をチェック
//        if url.pathExtension == "logoproj" {
//            // プロジェクトファイルの場合
//            openProjectFile(url)
//        } else if ["png", "jpg", "jpeg"].contains(url.pathExtension.lowercased()) {
//            // 画像ファイルの場合
//            importImage(url)
//        }
//    }
//    
//    /// プロジェクトファイルを開く
//    private func openProjectFile(_ url: URL) {
//        // ファイルコーディネーターを使用してファイルアクセスを調整
//        let coordinator = NSFileCoordinator(filePresenter: nil)
//        var error: NSError? = nil
//        
//        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &error) { (readURL) in
//            do {
//                // ファイルからデータを読み込み
//                let data = try Data(contentsOf: readURL)
//                
//                // JSONデコーダーでプロジェクトオブジェクトに変換
//                let decoder = JSONDecoder()
//                let project = try decoder.decode(LogoProject.self, from: data)
//                
//                // メインスレッドでUIを更新
//                DispatchQueue.main.async {
//                    // ルートビューコントローラーがUIHostingControllerであることを確認
//                    if let hostingController = self.window?.rootViewController as? UIHostingController<EditorView> {
//                        // 新しいEditorViewModelを作成してプロジェクトを設定
//                        let newViewModel = EditorViewModel(project: project)
//                        
//                        // ルートビューを更新
//                        hostingController.rootView = EditorView(viewModel: newViewModel)
//                    }
//                }
//            } catch {
//                print("Failed to open project file: \(error)")
//                // エラー処理（アラート表示など）
//                showErrorAlert(message: "プロジェクトファイルを開けませんでした")
//            }
//        }
//        
//        if let error = error {
//            print("File coordinator error: \(error)")
//            showErrorAlert(message: "ファイルへのアクセスエラー")
//        }
//    }
//    
//    /// 画像ファイルをインポート
//    private func importImage(_ url: URL) {
//        // ファイルコーディネーターを使用してファイルアクセスを調整
//        let coordinator = NSFileCoordinator(filePresenter: nil)
//        var error: NSError? = nil
//        
//        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &error) { (readURL) in
//            do {
//                // 画像データを読み込み
//                let data = try Data(contentsOf: readURL)
//                
//                if let image = UIImage(data: data) {
//                    // AssetManagerを使用して画像を保存
//                    let assetName = url.deletingPathExtension().lastPathComponent
//                    let success = AssetManager.shared.saveImage(image, name: assetName)
//                    
//                    if success {
//                        // メインスレッドでUIを更新
//                        DispatchQueue.main.async {
//                            // 必要に応じてUIを更新
//                            // 例：画像ライブラリの更新や、新しい画像要素の追加など
//                        }
//                    }
//                }
//            } catch {
//                print("Failed to import image: \(error)")
//                showErrorAlert(message: "画像をインポートできませんでした")
//            }
//        }
//        
//        if let error = error {
//            print("File coordinator error: \(error)")
//            showErrorAlert(message: "ファイルへのアクセスエラー")
//        }
//    }
//    
//    // MARK: - ヘルパーメソッド
//    
//    /// 自動保存タイマーを再開
//    private func resumeAutosaveTimer() {
//        //
//        // NotificationCenterを使用してタイマー再開通知を送信
//        NotificationCenter.default.post(name: NSNotification.Name("ResumeAutosaveTimer"), object: nil)
//    }
//    
//    /// 自動保存タイマーを一時停止
//    private func pauseAutosaveTimer() {
//        //
//        // NotificationCenterを使用してタイマー停止通知を送信
//        NotificationCenter.default.post(name: NSNotification.Name("PauseAutosaveTimer"), object: nil)
//    }
//    
//    /// 現在のプロジェクトの状態を保存
//    private func saveCurrentProjectState() {
//        //
//        // NotificationCenterを使用して保存通知を送信
//        NotificationCenter.default.post(name: NSNotification.Name("SaveCurrentProject"), object: nil)
//    }
//    
//    /// データの更新が必要かチェックして更新
//    private func refreshDataIfNeeded() {
//        //
//        // 長時間バックグラウンドにいた場合、データを更新
//    }
//    
//    /// アクティビティモニタリングを再開
//    private func resumeActivityMonitoring() {
//        //
//        // 分析やパフォーマンス監視を再開
//    }
//    
//    /// エラーアラートを表示
//    private func showErrorAlert(message: String) {
//        DispatchQueue.main.async {
//            // UIAlertControllerを使用してアラートを表示
//            if let rootViewController = self.window?.rootViewController {
//                let alert = UIAlertController(
//                    title: "エラー",
//                    message: message,
//                    preferredStyle: .alert
//                )
//                
//                alert.addAction(UIAlertAction(title: "OK", style: .default))
//                rootViewController.present(alert, animated: true)
//            }
//        }
//    }
//}
