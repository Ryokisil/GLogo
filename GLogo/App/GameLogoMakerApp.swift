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

    var body: some Scene {
        WindowGroup {
            EditorView(viewModel: editorViewModel)
                .environment(\.locale, AppLanguage.from(rawValue: appLanguageRawValue).resolvedLocale)
        }
    }
}
