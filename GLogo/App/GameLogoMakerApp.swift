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
    @StateObject private var editorViewModel = EditorViewModel()

    var body: some Scene {
        WindowGroup {
            EditorView(viewModel: editorViewModel)
        }
    }
}
