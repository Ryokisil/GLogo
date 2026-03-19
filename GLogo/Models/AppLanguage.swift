//
//  AppLanguage.swift
//  GLogo
//
//  概要:
//  アプリ内言語設定を表すモデルです。
//  App Settings から system / en / ja を選択し、
//  `.environment(\.locale, ...)` でアプリ全体の UI 言語を切り替えます。
//

import Foundation

/// アプリ内言語設定
///
/// `@AppStorage(AppLanguage.storageKey)` で永続化し、
/// `resolvedLocale` を SwiftUI 環境に注入して言語を切り替えます。
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    /// 端末の言語設定に追従
    case system
    /// 英語
    case english = "en"
    /// 日本語
    case japanese = "ja"

    var id: String { rawValue }

    /// 表示用の言語名
    ///
    /// `.system` はローカライズキーを解決し、
    /// 個別言語は常にその言語の自称表記で返します。
    var displayName: String {
        switch self {
        case .system:  return String(localized: "settings.language.system")
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }

    /// UserDefaults / @AppStorage の保存キー
    static let storageKey = "appLanguage"

    /// 選択に応じた `Locale` を返す
    ///
    /// - `.system`: iOS がアプリに適用した言語を使用
    /// - `.english` / `.japanese`: 指定言語の Locale を直接返す
    var resolvedLocale: Locale {
        switch self {
        case .system:
            let langCode = Bundle.main.preferredLocalizations.first ?? "en"
            return Locale(identifier: langCode)
        case .english, .japanese:
            return Locale(identifier: rawValue)
        }
    }

    /// `@AppStorage` の raw 値から `AppLanguage` を復元する
    ///
    /// 不正な値が保存されている場合は `.system` にフォールバックします。
    static func from(rawValue: String) -> AppLanguage {
        AppLanguage(rawValue: rawValue) ?? .system
    }

    /// アプリが実際に使用中の言語をネイティブ表記で返す
    ///
    /// `Bundle.main.preferredLocalizations` を参照するため、
    /// iOS のアプリ別言語設定やフォールバックを正しく反映します。
    static var currentAppLanguageLabel: String {
        let langCode = Bundle.main.preferredLocalizations.first ?? "en"
        let nativeLocale = Locale(identifier: langCode)
        return nativeLocale.localizedString(forLanguageCode: langCode)?.localizedCapitalized ?? langCode
    }
}
