//
//  AppDelegate.swift
//
//  概要:
//  このファイルはアプリのエントリーポイントとなるAppDelegateクラスを定義しています。
//  アプリのライフサイクルイベント（起動、バックグラウンド移行、終了など）を管理し、
//  必要な初期化処理や終了時の処理を行います。
//

import UIKit
import OSLog

class AppDelegate: UIResponder, UIApplicationDelegate {
    private let logger = Logger(subsystem: "com.silvia.GLogo", category: "AppLifecycle")
    
    // MARK: - アプリ起動時の処理
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // アプリの起動時に実行される処理
        
        // アプリのデータディレクトリを確保
        setupAppDirectories()
        setupDefaultSettings()
        logAppLaunch()
        
        return true
    }
    
    // MARK: - UISceneSessionのライフサイクル
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    /// アプリ全体でサポートする画面向きを返す
    /// - Parameters:
    ///   - application: 現在のアプリケーション
    ///   - window: 対象ウィンドウ
    /// - Returns: 縦向き固定の向きマスク
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .portrait
    }
    
    // MARK: - 初期化メソッド
    
    /// アプリのデータディレクトリを設定
    private func setupAppDirectories() {
        _ = ProjectStorage.shared
        _ = AssetManager.shared
        createDirectoryIfNeeded("Temp")
        createDirectoryIfNeeded("Cache")
    }
    
    /// 指定されたディレクトリが存在しない場合に作成
    private func createDirectoryIfNeeded(_ directoryName: String) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directoryURL = documentsURL.appendingPathComponent(directoryName)
        
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            do {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                logger.error("ディレクトリ作成に失敗: name=\(directoryName, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    /// デフォルト設定の初期化
    private func setupDefaultSettings() {
        // UserDefaultsの初期設定
        let defaults = UserDefaults.standard
        
        // 初回起動かどうかをチェック
        if !defaults.bool(forKey: "hasLaunchedBefore") {
            // 初回起動時の設定
            defaults.set(true, forKey: "hasLaunchedBefore")
            defaults.set(Date(), forKey: "firstLaunchDate")
            
            // デフォルト設定の適用
            applyDefaultSettings(defaults)
        }
        
        // アプリバージョンの保存（アップデート検出用）
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            let previousVersion = defaults.string(forKey: "appVersion")
            if previousVersion != appVersion {
                // アプリが更新された場合の処理
                handleAppUpdate(from: previousVersion, to: appVersion)
                defaults.set(appVersion, forKey: "appVersion")
            }
        }
        
        // 設定の同期
        defaults.synchronize()
    }
    
    /// デフォルト設定を適用
    private func applyDefaultSettings(_ defaults: UserDefaults) {
        // エディタ関連の設定
        defaults.set(true, forKey: "showGrid")
        defaults.set(false, forKey: "snapToGrid")
        defaults.set(20, forKey: "gridSize")
        
        // エクスポート関連の設定
        defaults.set("png", forKey: "defaultExportFormat")
        defaults.set(1024, forKey: "defaultExportWidth")
        defaults.set(1024, forKey: "defaultExportHeight")
        defaults.set(0.9, forKey: "defaultJpegQuality")
        
        // その他のアプリ設定
        defaults.set(true, forKey: "autosaveEnabled")
        defaults.set(300, forKey: "autosaveInterval") // 5分間隔
    }
    
    /// アプリのアップデート時の処理
    private func handleAppUpdate(from _: String?, to _: String) {
        // バージョンに応じた移行処理などを実装可能
        
        // 例：データ構造の変更が必要な場合のマイグレーション
        // if oldVersion?.starts(with: "1.") == true && newVersion.starts(with: "2.") {
        //     migrateDataFromV1ToV2()
        // }
    }
    
    /// アプリの起動ログを記録
    private func logAppLaunch() {
        // アプリの起動回数を記録
        let defaults = UserDefaults.standard
        let launchCount = defaults.integer(forKey: "appLaunchCount") + 1
        defaults.set(launchCount, forKey: "appLaunchCount")
    }
    
    // MARK: - アプリ終了時の処理
    
    func applicationWillTerminate(_ application: UIApplication) {
        // アプリが終了する前に呼ばれる
        
        // 未保存データの保存
        saveUnsavedData()
        
        // テンポラリファイルのクリーンアップ
        cleanupTemporaryFiles()
    }
    
    /// 未保存データを保存
    private func saveUnsavedData() {
       
    }
    
    /// 一時ファイルをクリーンアップ
    private func cleanupTemporaryFiles() {
        let fileManager = FileManager.default
        let tempDirectoryURL = fileManager.temporaryDirectory
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(
                at: tempDirectoryURL,
                includingPropertiesForKeys: nil
            )
            
            // アプリが作成した一時ファイルを削除
            for fileURL in tempFiles where fileURL.lastPathComponent.hasPrefix("GameLogoMaker_") {
                try? fileManager.removeItem(at: fileURL)
            }
        } catch {
            logger.error("一時ファイル削除に失敗: \(error.localizedDescription, privacy: .public)")
        }
    }
}
