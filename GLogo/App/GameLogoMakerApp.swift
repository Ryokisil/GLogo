//
//  GameLogoMakerApp.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはアプリのエントリーポイントとしてEditorViewを起動する。
//

import SwiftUI

@main
struct GameLogoMakerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.system.rawValue
    @StateObject private var editorViewModel = EditorViewModel()

    init() {
        #if DEBUG
        applyUITestLaunchArguments()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            EditorView(viewModel: editorViewModel)
                .environment(\.locale, AppLanguage.from(rawValue: appLanguageRawValue).resolvedLocale)
        }
    }

    // MARK: - UIテスト用

    #if DEBUG
    /// UIテストの launch argument から UserDefaults を設定する
    private func applyUITestLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        // "-key" "value" 形式の引数を UserDefaults に反映
        let boolKeys: Set<String> = ["hasSeenEditorIntro"]
        for (index, arg) in args.enumerated() where arg.hasPrefix("-") {
            let key = String(arg.dropFirst())
            guard boolKeys.contains(key),
                  index + 1 < args.count else { continue }
            let value = args[index + 1]
            if value.uppercased() == "YES" || value == "1" || value.uppercased() == "TRUE" {
                UserDefaults.standard.set(true, forKey: key)
            }
        }
    }
    #endif
}
