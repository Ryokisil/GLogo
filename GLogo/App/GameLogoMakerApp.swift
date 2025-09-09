//
//  GameLogoMakerApp.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはSwiftUIアプリケーションのエントリーポイントを定義
//  iOS 14以降のSwiftUIライフサイクルに対応し、WindowGroupとSceneを管理
//  AppDelegateと連携してアプリケーションの状態を管理
//

import SwiftUI
import Combine

/// メインアプリケーション構造体
@main
struct GameLogoMakerApp: App {
    /// UIKit AppDelegateとの連携
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    /// 環境値を管理するための状態オブジェクト
    @StateObject private var appSettings = AppSettings()
    
    /// アプリケーションのシーン定義
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appSettings)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // アプリがアクティブになった時の処理
                    checkForUpdates()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    // アプリが非アクティブになった時の処理
                    saveAppState()
                }
        }
        .commands {
            // macOS Catalystの場合のみメニューコマンドを追加
#if targetEnvironment(macCatalyst)
            SidebarCommands()
            
            CommandGroup(after: .newItem) {
                Button("新規テンプレート...") {
                    NotificationCenter.default.post(name: Notification.Name("ShowTemplates"), object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Divider()
                
                Button("設定...") {
                    NotificationCenter.default.post(name: Notification.Name("ShowSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandGroup(after: .pasteboard) {
                Button("画像をインポート...") {
                    NotificationCenter.default.post(name: Notification.Name("ImportImage"), object: nil)
                }
                .keyboardShortcut("i", modifiers: .command)
            }
            
            CommandMenu("表示") {
                Button("グリッドを表示") {
                    appSettings.showGrid.toggle()
                }
                .keyboardShortcut("g", modifiers: .command)
                
                Button("グリッドにスナップ") {
                    appSettings.snapToGrid.toggle()
                }
                .keyboardShortcut("g", modifiers: [.command, .option])
                
                Divider()
                
                Button("ズームイン") {
                    NotificationCenter.default.post(name: Notification.Name("ZoomIn"), object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("ズームアウト") {
                    NotificationCenter.default.post(name: Notification.Name("ZoomOut"), object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("ズームをリセット") {
                    NotificationCenter.default.post(name: Notification.Name("ZoomReset"), object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            
            CommandMenu("要素") {
                Button("前面へ") {
                    NotificationCenter.default.post(name: Notification.Name("BringToFront"), object: nil)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                
                Button("背面へ") {
                    NotificationCenter.default.post(name: Notification.Name("SendToBack"), object: nil)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                
                Divider()
                
                Button("複製") {
                    NotificationCenter.default.post(name: Notification.Name("DuplicateElement"), object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Button("削除") {
                    NotificationCenter.default.post(name: Notification.Name("DeleteElement"), object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
#endif
        }
    }
    
    /// メインコンテンツビュー
    struct ContentView: View {
        @EnvironmentObject var appSettings: AppSettings
        @StateObject private var editorViewModel = EditorViewModel()
        
        var body: some View {
            EditorView(viewModel: editorViewModel)
            // 通知リスナーの設定
//                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SaveCurrentProject"))) { _ in
//                    saveProject()
//                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ImportImage"))) { _ in
                    importImage()
                }
                .onAppear {
                    // 初回表示時の処理
                    setupNotificationListeners()
                }
        }
        
        /// プロジェクトを保存
//        private func saveProject() {
//            editorViewModel.saveProject { success in
//                print("Project saved: \(success)")
//            }
//        }
        
        /// 画像をインポート
        private func importImage() {
            
        }
        
        /// 通知リスナーの設定
        private func setupNotificationListeners() {
            
        }
    }
    
    /// アップデートを確認
    private func checkForUpdates() {
        // アプリの更新確認ロジック（必要に応じて）
    }
    
    /// アプリの状態を保存
    private func saveAppState() {
        // アプリの状態保存ロジック
        UserDefaults.standard.synchronize()
    }
}

/// アプリ全体の設定を管理するクラス
class AppSettings: ObservableObject {
    /// グリッド表示
    @Published var showGrid: Bool = UserDefaults.standard.bool(forKey: "showGrid")
    
    /// グリッドへのスナップ
    @Published var snapToGrid: Bool = UserDefaults.standard.bool(forKey: "snapToGrid")
    
    /// グリッドサイズ
    @Published var gridSize: Int = UserDefaults.standard.integer(forKey: "gridSize")
    
    /// 設定が変更されたときにUserDefaultsに保存
    init() {
        // 値が変更されたらUserDefaultsに保存するPublisherを設定
        $showGrid
            .dropFirst() // 初期値による発火を無視
            .sink { UserDefaults.standard.set($0, forKey: "showGrid") }
            .store(in: &cancellables)
        
        $snapToGrid
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "snapToGrid") }
            .store(in: &cancellables)
        
        $gridSize
            .dropFirst()
            .sink { UserDefaults.standard.set($0, forKey: "gridSize") }
            .store(in: &cancellables)
    }
    
    /// Publisherのキャンセル用ストア
    private var cancellables = Set<AnyCancellable>()
}
