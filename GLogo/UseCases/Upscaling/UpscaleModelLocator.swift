//
//  UpscaleModelLocator.swift
//  GLogo
//
//  概要:
//  このファイルは高画質化用 Core ML モデルの配置場所を解決するロケーターを定義します。
//  `realesr-general-x4v3.mlmodelc` をアプリバンドル内から安定して見つけるための探索処理を集約します。
//

import Foundation

/// 高画質化モデルのバンドル探索を担当するロケーター
struct UpscaleModelLocator {
    let preferredSubdirectory: String?

    /// ロケーターを生成する
    /// - Parameters:
    ///   - preferredSubdirectory: まず探索するバンドル内サブディレクトリ
    /// - Returns: 生成されたロケーター
    init(preferredSubdirectory: String? = "Resources/MLModels") {
        self.preferredSubdirectory = preferredSubdirectory
    }

    /// コンパイル済み Core ML モデルの URL を解決する
    /// - Parameters:
    ///   - name: モデル名
    ///   - bundle: 探索対象バンドル
    /// - Returns: 見つかったモデル URL。未配置時は nil
    func compiledModelURL(
        named name: String,
        in bundle: Bundle = .main
    ) -> URL? {
        if let preferredSubdirectory,
           let preferredURL = bundle.url(
                forResource: name,
                withExtension: "mlmodelc",
                subdirectory: preferredSubdirectory
           ) {
            return preferredURL
        }

        if let directURL = bundle.url(forResource: name, withExtension: "mlmodelc") {
            return directURL
        }

        guard let resourceURL = bundle.resourceURL else {
            return nil
        }

        let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: nil
        )

        while let itemURL = enumerator?.nextObject() as? URL {
            guard itemURL.lastPathComponent == "\(name).mlmodelc" else {
                continue
            }
            return itemURL
        }

        return nil
    }
}
