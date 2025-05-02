//
//  LogoProject.swift
//  GameLogoMaker
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
    /// プロジェクト名
    var name: String = ""
    
    /// プロジェクトのすべての要素
    var elements: [LogoElement] = []
    
    /// 背景設定
    var backgroundSettings: BackgroundSettings = BackgroundSettings()
    
    /// キャンバスサイズ
    var canvasSize: CGSize = CGSize(width: 1024, height: 1024)
    
    /// 作成日時
    var createdAt: Date = Date()
    
    /// 最終更新日時
    var updatedAt: Date = Date()
    
    /// プロジェクトのユニークID
    var id = UUID()
    
    /// エンコード用のコーディングキー
    enum CodingKeys: String, CodingKey {
        case name, elements, backgroundSettings, canvasSize, createdAt, updatedAt, id
    }
    
    /// カスタムエンコーダー（CGSizeのエンコード対応）
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(elements, forKey: .elements)
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
        elements = try container.decode([LogoElement].self, forKey: .elements)
        backgroundSettings = try container.decode(BackgroundSettings.self, forKey: .backgroundSettings)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        id = try container.decode(UUID.self, forKey: .id)
        
        // CGSizeのデコード
        let sizeDict = try container.decode([String: CGFloat].self, forKey: .canvasSize)
        canvasSize = CGSize(width: sizeDict["width"] ?? 1024, height: sizeDict["height"] ?? 1024)
    }
    
    /// 新しいプロジェクトの初期化
    init(name: String = "", canvasSize: CGSize = CGSize(width: 1024, height: 1024)) {
        self.name = name
        self.canvasSize = canvasSize
    }
    
    /// プロジェクトに要素を追加
    func addElement(_ element: LogoElement) {
        elements.append(element)
        updatedAt = Date()
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
