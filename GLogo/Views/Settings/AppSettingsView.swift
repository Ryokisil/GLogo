//
//  AppSettingsView.swift
//  GLogo
//
//  概要:
//  エディタから開くアプリ設定画面を提供します。
//  言語選択、使い方ガイド、オープンソースライセンス、アプリバージョンを集約します。
//

import SwiftUI

/// アプリ設定画面
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.system.rawValue

    let onRequestOpenEditorGuide: () -> Void

    /// 現在選択中の言語設定
    private var selectedAppLanguage: AppLanguage {
        AppLanguage.from(rawValue: appLanguageRawValue)
    }

    /// Picker 用の言語バインディング
    private var selectedAppLanguageBinding: Binding<AppLanguage> {
        Binding(
            get: { selectedAppLanguage },
            set: { appLanguageRawValue = $0.rawValue }
        )
    }

    /// 設定行右側に表示する言語名
    private var languageStatusText: String {
        switch selectedAppLanguage {
        case .system:
            return AppLanguage.currentAppLanguageLabel
        case .english, .japanese:
            return selectedAppLanguage.displayName
        }
    }

    private var appVersionText: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(shortVersion) (\(buildNumber))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("settings.section.preferences") {
                    Picker(selection: selectedAppLanguageBinding) {
                        ForEach(AppLanguage.allCases) { language in
                            languageOptionLabel(for: language)
                                .tag(language)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.language.title")
                                    .font(.body.weight(.medium))
                                Text("settings.language.description")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(verbatim: languageStatusText)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .pickerStyle(.navigationLink)
                }

                Section("settings.section.support") {
                    Button {
                        onRequestOpenEditorGuide()
                        dismiss()
                    } label: {
                        settingsRow(
                            title: "settings.editorGuide.title",
                            subtitle: "settings.editorGuide.subtitle",
                            systemImage: "questionmark.circle"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        OpenSourceLicenseView()
                    } label: {
                        settingsRow(
                            title: "settings.license.title",
                            subtitle: "settings.license.subtitle",
                            systemImage: "doc.text"
                        )
                    }
                }

                Section("settings.section.about") {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("settings.version.title")
                                .font(.body.weight(.medium))
                            Text(verbatim: appVersionText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.close") {
                        dismiss()
                    }
                }
            }
        }
        .id(appLanguageRawValue)
        .environment(\.locale, selectedAppLanguage.resolvedLocale)
    }

    /// 設定行の共通表示を生成します。
    /// - Parameters:
    ///   - title: 行タイトル（ローカライズキー）
    ///   - subtitle: 補足説明（ローカライズキー）
    ///   - systemImage: 左側に表示するSF Symbols名
    /// - Returns: 設定行ビュー
    @ViewBuilder
    private func settingsRow(title: LocalizedStringKey, subtitle: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    /// 言語選択肢の表示名を生成します。
    /// - Parameters:
    ///   - language: 表示対象の言語設定
    /// - Returns: 言語名ビュー
    @ViewBuilder
    private func languageOptionLabel(for language: AppLanguage) -> some View {
        switch language {
        case .system:
            Text("settings.language.system")
        case .english, .japanese:
            Text(verbatim: language.displayName)
        }
    }
}

#Preview {
    AppSettingsView(onRequestOpenEditorGuide: {})
}
