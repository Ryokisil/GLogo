//
//  LogoProject.swift
//
//  概要:
//  このファイルはロゴプロジェクト全体を表すモデルクラスを定義しています。
//  プロジェクト名、キャンバスサイズ、背景設定、およびすべてのロゴ要素（テキスト、図形、画像など）
//  を管理します。また、プロジェクトの保存、読み込み、複製のための機能も提供します。
//

import Foundation
import UIKit

/// ロゴプロジェクト全体を表すモデルクラス
class LogoProject: Codable {
    /// 要素型を保持して保存するためのラッパー
    private enum ElementEnvelope: Codable {
        case image(ImageElement)
        case text(TextElement)
        case shape(ShapeElement)
        case base(LogoElement)

        /// ラッパー種別
        private enum ElementType: String, Codable {
            case image
            case text
            case shape
            case base
        }

        /// エンコードキー
        private enum CodingKeys: String, CodingKey {
            case type
            case payload
        }

        /// 要素からラッパーを生成
        /// - Parameters:
        ///   - element: ラップ対象の要素
        /// - Returns: なし
        init(element: LogoElement) {
            switch element {
            case let image as ImageElement:
                self = .image(image)
            case let text as TextElement:
                self = .text(text)
            case let shape as ShapeElement:
                self = .shape(shape)
            default:
                self = .base(element)
            }
        }

        /// ラッパーから要素を取り出す
        /// - Parameters: なし
        /// - Returns: 復元された要素
        var element: LogoElement {
            switch self {
            case .image(let image):
                return image
            case .text(let text):
                return text
            case .shape(let shape):
                return shape
            case .base(let base):
                return base
            }
        }

        /// 要素ラッパーのエンコード
        /// - Parameters:
        ///   - encoder: エンコーダ
        /// - Returns: なし
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .image(let image):
                try container.encode(ElementType.image, forKey: .type)
                try container.encode(image, forKey: .payload)
            case .text(let text):
                try container.encode(ElementType.text, forKey: .type)
                try container.encode(text, forKey: .payload)
            case .shape(let shape):
                try container.encode(ElementType.shape, forKey: .type)
                try container.encode(shape, forKey: .payload)
            case .base(let base):
                try container.encode(ElementType.base, forKey: .type)
                try container.encode(base, forKey: .payload)
            }
        }

        /// 要素ラッパーのデコード
        /// - Parameters:
        ///   - decoder: デコーダ
        /// - Returns: なし
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(ElementType.self, forKey: .type)

            switch type {
            case .image:
                self = .image(try container.decode(ImageElement.self, forKey: .payload))
            case .text:
                self = .text(try container.decode(TextElement.self, forKey: .payload))
            case .shape:
                self = .shape(try container.decode(ShapeElement.self, forKey: .payload))
            case .base:
                self = .base(try container.decode(LogoElement.self, forKey: .payload))
            }
        }
    }

    /// 旧保存形式（type discriminator なし）復元用ラッパー
    private struct LegacyElementEnvelope: Decodable {
        /// 復元された要素
        let element: LogoElement

        /// 旧形式要素をキー判定して復元
        /// - Parameters:
        ///   - decoder: デコーダ
        /// - Returns: なし
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: AnyCodingKey.self)
            if container.contains(AnyCodingKey("shapeType")) {
                element = try ShapeElement(from: decoder)
                return
            }

            if container.contains(AnyCodingKey("text")),
               container.contains(AnyCodingKey("fontName")) {
                element = try TextElement(from: decoder)
                return
            }

            if container.contains(AnyCodingKey("imageData"))
                || container.contains(AnyCodingKey("imageFileName"))
                || container.contains(AnyCodingKey("originalImageIdentifier"))
                || container.contains(AnyCodingKey("originalImagePath"))
                || container.contains(AnyCodingKey("originalImageURL")) {
                element = try ImageElement(from: decoder)
                return
            }

            element = try LogoElement(from: decoder)
        }
    }

    /// 任意キーアクセス用のCodingKey
    private struct AnyCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init(_ string: String) {
            self.stringValue = string
            self.intValue = nil
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }

    /// プロジェクト名
    var name: String = ""
    
    /// プロジェクトのすべての要素
    var elements: [LogoElement] = []
    
    /// 背景設定
    var backgroundSettings: BackgroundSettings = BackgroundSettings()
    
    /// キャンバスサイズ
    var canvasSize: CGSize = CGSize(width: 3840, height: 2160)
    
    /// 作成日時
    var createdAt: Date = Date()
    
    /// 最終更新日時
    var updatedAt: Date = Date()
    
    /// プロジェクトのユニークID
    var id = UUID()
    
    /// エンコード用のコーディングキー
    /// - Note: `elements` は type/payload 付きの新形式で保存する。デコードは旧形式をフォールバック対応。
    enum CodingKeys: String, CodingKey {
        case name, elements, backgroundSettings, canvasSize, createdAt, updatedAt, id
    }
    
    /// カスタムエンコーダー（CGSizeのエンコード対応）
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        let wrappedElements = elements.map { ElementEnvelope(element: $0) }
        try container.encode(wrappedElements, forKey: .elements)
        try container.encode(backgroundSettings, forKey: .backgroundSettings)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(id, forKey: .id)
        
        // CGSizeのエンコード
        let sizeDict = ["width": canvasSize.width, "height": canvasSize.height]
        try container.encode(sizeDict, forKey: .canvasSize)
    }
    
    /// カスタムデコーダー（CGSizeのデコード対応）
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)

        do {
            let wrappedElements = try container.decode([ElementEnvelope].self, forKey: .elements)
            elements = wrappedElements.map(\.element)
        } catch DecodingError.keyNotFound(let missingKey, _) where missingKey.stringValue == "type" {
            let legacyElements = try container.decode([LegacyElementEnvelope].self, forKey: .elements)
            elements = legacyElements.map(\.element)
        } catch {
            throw error
        }
        backgroundSettings = try container.decode(BackgroundSettings.self, forKey: .backgroundSettings)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        id = try container.decode(UUID.self, forKey: .id)
        
        // CGSizeのデコード
        let sizeDict = try container.decode([String: CGFloat].self, forKey: .canvasSize)
        canvasSize = CGSize(width: sizeDict["width"] ?? 1024, height: sizeDict["height"] ?? 1024)
    }
    
    /// 新しいプロジェクトの初期化
    init(name: String = "", canvasSize: CGSize = CGSize(width: 3840, height: 2160)) {
        self.name = name
        self.canvasSize = canvasSize
    }
    
    /// プロジェクトに要素を追加
    func addElement(_ element: LogoElement) {
        elements.append(element)
        updatedAt = Date()
    }

    /// 指定したIDの要素を取得
    /// - Parameters:
    ///   - id: 要素ID
    /// - Returns: 該当する要素（存在しない場合はnil）
    func element(for id: UUID) -> LogoElement? {
        elements.first { $0.id == id }
    }

    /// 指定した型として要素を取得
    /// - Parameters:
    ///   - id: 要素ID
    ///   - type: 取得したい要素の型
    /// - Returns: 型変換に成功した要素（存在しない場合はnil）
    func element<T: LogoElement>(for id: UUID, as type: T.Type) -> T? {
        element(for: id) as? T
    }
    
    /// 指定したIDの要素を削除
    func removeElement(withId id: UUID) {
        elements.removeAll { $0.id == id }
        updatedAt = Date()
    }
    
    /// プロジェクトの複製を作成
    func duplicate(withName newName: String? = nil) -> LogoProject {
        let copy = LogoProject(name: newName ?? "\(name) Copy", canvasSize: canvasSize)
        copy.elements = elements.map { $0.copy() }
        copy.backgroundSettings = backgroundSettings
        copy.createdAt = Date()
        copy.updatedAt = Date()
        return copy
    }
}
