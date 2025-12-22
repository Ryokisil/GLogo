//
//  EventSourcing.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはイベントソーシングに基づくシンプルなアンドゥ・リドゥ機能を実装
//  コマンドパターンより実装が簡単、「何をしたか」を明確に記録します。
//

import Foundation
import UIKit

/// エディタイベントのプロトコル - すべてのイベントが実装される必要がある
protocol EditorEvent: Codable {
    /// イベントを識別するための名前
    var eventName: String { get }
    
    /// イベントが発生した日時
    var timestamp: Date { get }
    
    /// イベントを適用するメソッド
    func apply(to project: LogoProject)
    
    /// イベントを元に戻すメソッド
    func revert(from project: LogoProject)
    
    /// イベントの説明
    var description: String { get }
}

/// エディタの履歴を管理するクラス
class EditorHistory {
    /// 実行済みイベントのスタック
    private(set) var eventStack: [EditorEvent] = []
    
    /// 取り消されたイベントのスタック（リドゥ用）
    private var undoneEventStack: [EditorEvent] = []
    
    /// 履歴の最大数
    private let maxHistoryCount: Int
    
    /// プロジェクト参照
    private var project: LogoProject?
    
    /// イニシャライザ
    init(project: LogoProject?, maxHistoryCount: Int = 100) {
        self.project = project
        self.maxHistoryCount = maxHistoryCount
    }
    
    /// プロジェクト参照を更新
    func setProject(_ project: LogoProject) {
        self.project = project
    }
    
    /// イベントを記録して適用
    func recordAndApply(_ event: EditorEvent) {
        guard let project = project else { return }
        
        // イベントをプロジェクトに適用
        event.apply(to: project)
        
        // イベントスタックに追加
        eventStack.append(event)
        
        // 履歴の最大数を超えた場合、古いものから削除
        if eventStack.count > maxHistoryCount {
            eventStack.removeFirst()
        }
        
        // 取り消し履歴をクリア
        undoneEventStack.removeAll()
    }
    
    /// アンドゥ操作 使いたい時だけ使う設計なので戻り値をBool型に。リドゥも同じ あと戻り値破棄しても警告出ないようにdiscardableResult使用
    @discardableResult
    func undo() -> Bool {
        
        guard let project = project, let lastEvent = eventStack.popLast() else {
            return false
        }
        
        // ここでプロジェクトの要素数をチェック
        let beforeCount = project.elements.count
        
        // イベントの効果を元に戻す
        lastEvent.revert(from: project)
        
        // ここでプロジェクトの要素数をチェック
        let afterCount = project.elements.count
        if beforeCount != afterCount {
            print("DEBUG: 警告 - revert前後で要素数が変化: \(beforeCount) -> \(afterCount)")
        }
        
        // 取り消し履歴に追加
        undoneEventStack.append(lastEvent)
        
        return true
    }
    
    /// リドゥ操作
    @discardableResult
    func redo() -> Bool {
        guard let project = project, let lastUndoneEvent = undoneEventStack.popLast() else {
            return false
        }
        
        // 取り消したイベントを再適用
        lastUndoneEvent.apply(to: project)
        
        // イベント履歴に追加
        eventStack.append(lastUndoneEvent)
        
        return true
    }
    
    /// アンドゥ可能かどうか
    var canUndo: Bool {
        return !eventStack.isEmpty
    }
    
    /// リドゥ可能かどうか
    var canRedo: Bool {
        return !undoneEventStack.isEmpty
    }
    
    /// 履歴をクリア
    func clearHistory() {
        eventStack.removeAll()
        undoneEventStack.removeAll()
    }
    
    /// アンドゥスタックの深さ（履歴の数）
    var undoCount: Int {
        return eventStack.count
    }
    
    /// リドゥスタックの深さ
    var redoCount: Int {
        return undoneEventStack.count
    }
    
    /// 履歴の説明を取得（UIに表示可能）
    func getHistoryDescriptions() -> [String] {
        return eventStack.map { $0.description }
    }
    
    func getEventNames() -> [String] {
        return eventStack.map { $0.eventName }
    }
}

// MARK: - 具体的なイベント実装

/// 要素追加イベント
struct ElementAddedEvent: EditorEvent {
    var eventName = "ElementAdded"
    var timestamp = Date()
    let element: LogoElement
    
    var description: String {
        return "\(element.name)を追加しました"
    }
    
    func apply(to project: LogoProject) {
        project.elements.append(element)
    }
    
    func revert(from project: LogoProject) {
        project.elements.removeAll { $0.id == element.id }
    }
}

/// 要素削除イベント
struct ElementRemovedEvent: EditorEvent {
    var eventName = "ElementRemoved"
    var timestamp = Date()
    let element: LogoElement
    let index: Int
    
    var description: String {
        return "\(element.name)を削除しました"
    }
    
    func apply(to project: LogoProject) {
        project.elements.removeAll { $0.id == element.id }
    }
    
    func revert(from project: LogoProject) {
        // インデックスが範囲内かチェック
        let safeIndex = min(index, project.elements.count)
        project.elements.insert(element, at: safeIndex)
    }
}

/// 要素移動イベント
struct ElementMovedEvent: EditorEvent {
    var eventName = "ElementMoved"
    var timestamp = Date()
    let elementId: UUID
    let oldPosition: CGPoint
    let newPosition: CGPoint
    
    var description: String {
        return "要素を移動しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) {
            element.position = newPosition
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) {
            element.position = oldPosition
        }
    }
}

/// 要素サイズ変更イベント
struct ElementResizedEvent: EditorEvent {
    var eventName = "ElementResized"
    var timestamp = Date()
    let elementId: UUID
    let oldSize: CGSize
    let newSize: CGSize
    
    var description: String {
        return "要素のサイズを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) {
            element.size = newSize
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) {
            element.size = oldSize
        }
    }
}

/// 要素回転イベント
struct ElementRotatedEvent: EditorEvent {
    var eventName = "ElementRotated"
    var timestamp = Date()
    let elementId: UUID
    let oldRotation: CGFloat
    let newRotation: CGFloat
    
    var description: String {
        return "要素を回転しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) {
            element.rotation = newRotation
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) {
            element.rotation = oldRotation
        }
    }
}

/// テキスト内容変更イベント
struct TextContentChangedEvent: EditorEvent {
    var eventName = "TextContentChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldText: String
    let newText: String
    
    var description: String {
        return "テキストを編集しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? TextElement {
            element.text = newText
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? TextElement {
            element.text = oldText
        }
    }
}

/// テキスト色変更イベント
struct TextColorChangedEvent: EditorEvent {
    let eventName = "TextColorChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor
    
    var description: String {
        return "テキストの色を変更しました"
    }
    
    // Codable対応のためのプロパティ
    private enum CodingKeys: String, CodingKey {
        case timestamp, elementId
        case oldColorData, newColorData
    }
    
    // カスタムエンコーダー
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(elementId, forKey: .elementId)
        
        // UIColorのエンコード
        let oldColorData = try NSKeyedArchiver.archivedData(withRootObject: oldColor, requiringSecureCoding: false)
        let newColorData = try NSKeyedArchiver.archivedData(withRootObject: newColor, requiringSecureCoding: false)
        
        try container.encode(oldColorData, forKey: .oldColorData)
        try container.encode(newColorData, forKey: .newColorData)
    }
    
    // カスタムデコーダー
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        elementId = try container.decode(UUID.self, forKey: .elementId)
        
        // UIColorのデコード
        let oldColorData = try container.decode(Data.self, forKey: .oldColorData)
        let newColorData = try container.decode(Data.self, forKey: .newColorData)
        
        guard let decodedOldColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: oldColorData),
              let decodedNewColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: newColorData) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Failed to decode UIColor"
            ))
        }
        
        oldColor = decodedOldColor
        newColor = decodedNewColor
    }
    
    // 通常のイニシャライザ
    init(elementId: UUID, oldColor: UIColor, newColor: UIColor) {
        self.elementId = elementId
        self.oldColor = oldColor
        self.newColor = newColor
    }
    
    func apply(to project: LogoProject) {
        
        if let element = project.elements.first(where: { $0.id == elementId }) as? TextElement {
            element.textColor = newColor
        }
    }
    
    func revert(from project: LogoProject) {

        if let element = project.elements.first(where: { $0.id == elementId }) as? TextElement {
            element.textColor = oldColor
        }
    }
}

/// フォント変更イベント
struct FontChangedEvent: EditorEvent {
    var eventName = "FontChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldFontName: String
    let newFontName: String
    let oldFontSize: CGFloat
    let newFontSize: CGFloat
    
    var description: String {
        return "フォントを変更しました"
    }
    
    func apply(to project: LogoProject) {
        
        if let element = project.elements.first(where: { $0.id == elementId }) as? TextElement {
            element.fontName = newFontName
            element.fontSize = newFontSize
            print("DEBUG: フォントを\(newFontName)、サイズを\(newFontSize)に変更しました")
        }
    }
    
    func revert(from project: LogoProject) {
        
        if let element = project.elements.first(where: { $0.id == elementId }) as? TextElement {
            print("DEBUG: 要素が見つかりました: \(element.name)")
            element.fontName = oldFontName
            element.fontSize = oldFontSize
            print("DEBUG: フォントを\(oldFontName)、サイズを\(oldFontSize)に戻しました")
        }
    }
}

// MARK: - 図形に関するイベントの実装

/// 図形タイプ変更イベント
struct ShapeTypeChangedEvent: EditorEvent {
    var eventName = "ShapeTypeChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldType: ShapeType
    let newType: ShapeType
    
    var description: String {
        return "図形タイプを変更しました"
    }
    
    func apply(to project: LogoProject) {
        print("DEBUG: ShapeTypeChangedEvent.apply開始")
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.shapeType = newType
            print("DEBUG: 図形タイプを\(newType)に変更しました")
        } else {
            print("DEBUG: 警告 - 対象の要素がプロジェクト内に見つかりません")
        }
        print("DEBUG: ShapeTypeChangedEvent.apply終了")
    }
    
    func revert(from project: LogoProject) {
        print("DEBUG: ShapeTypeChangedEvent.revert開始")
        print("DEBUG: 対象要素ID: \(elementId)")
        
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            print("DEBUG: 要素が見つかりました: \(element.name)")
            element.shapeType = oldType
            print("DEBUG: 図形タイプを\(oldType)に戻しました")
        } else {
            print("DEBUG: 警告 - 対象の要素がプロジェクト内に見つかりません")
        }
        
        print("DEBUG: ShapeTypeChangedEvent.revert終了")
    }
}

/// 図形の塗りつぶし色変更イベント
struct ShapeFillColorChangedEvent: EditorEvent {
    let eventName = "ShapeFillColorChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor
    
    var description: String {
        return "図形の塗りつぶし色を変更しました"
    }
    
    // Codable対応のためのプロパティ
    private enum CodingKeys: String, CodingKey {
        case timestamp, elementId
        case oldColorData, newColorData
    }
    
    // カスタムエンコーダー
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(elementId, forKey: .elementId)
        
        // UIColorのエンコード
        let oldColorData = try NSKeyedArchiver.archivedData(withRootObject: oldColor, requiringSecureCoding: false)
        let newColorData = try NSKeyedArchiver.archivedData(withRootObject: newColor, requiringSecureCoding: false)
        
        try container.encode(oldColorData, forKey: .oldColorData)
        try container.encode(newColorData, forKey: .newColorData)
    }
    
    // カスタムデコーダー
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        elementId = try container.decode(UUID.self, forKey: .elementId)
        
        // UIColorのデコード
        let oldColorData = try container.decode(Data.self, forKey: .oldColorData)
        let newColorData = try container.decode(Data.self, forKey: .newColorData)
        
        guard let decodedOldColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: oldColorData),
              let decodedNewColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: newColorData) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Failed to decode UIColor"
            ))
        }
        
        oldColor = decodedOldColor
        newColor = decodedNewColor
    }
    
    // 通常のイニシャライザ
    init(elementId: UUID, oldColor: UIColor, newColor: UIColor) {
        self.elementId = elementId
        self.oldColor = oldColor
        self.newColor = newColor
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.fillColor = newColor
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.fillColor = oldColor
        }
    }
}

/// 図形の塗りつぶしモード変更イベント
struct ShapeFillModeChangedEvent: EditorEvent {
    var eventName = "ShapeFillModeChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldMode: FillMode
    let newMode: FillMode
    
    var description: String {
        return "図形の塗りつぶしモードを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.fillMode = newMode
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.fillMode = oldMode
        }
    }
}

/// 図形の枠線色変更イベント
struct ShapeStrokeColorChangedEvent: EditorEvent {
    let eventName = "ShapeStrokeColorChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor
    
    var description: String {
        return "図形の枠線色を変更しました"
    }
    
    // Codable対応のためのプロパティ
    private enum CodingKeys: String, CodingKey {
        case timestamp, elementId
        case oldColorData, newColorData
    }
    
    // カスタムエンコーダー
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(elementId, forKey: .elementId)
        
        // UIColorのエンコード
        let oldColorData = try NSKeyedArchiver.archivedData(withRootObject: oldColor, requiringSecureCoding: false)
        let newColorData = try NSKeyedArchiver.archivedData(withRootObject: newColor, requiringSecureCoding: false)
        
        try container.encode(oldColorData, forKey: .oldColorData)
        try container.encode(newColorData, forKey: .newColorData)
    }
    
    // カスタムデコーダー
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        elementId = try container.decode(UUID.self, forKey: .elementId)
        
        // UIColorのデコード
        let oldColorData = try container.decode(Data.self, forKey: .oldColorData)
        let newColorData = try container.decode(Data.self, forKey: .newColorData)
        
        guard let decodedOldColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: oldColorData),
              let decodedNewColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: newColorData) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Failed to decode UIColor"
            ))
        }
        
        oldColor = decodedOldColor
        newColor = decodedNewColor
    }
    
    // 通常のイニシャライザ
    init(elementId: UUID, oldColor: UIColor, newColor: UIColor) {
        self.elementId = elementId
        self.oldColor = oldColor
        self.newColor = newColor
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.strokeColor = newColor
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.strokeColor = oldColor
        }
    }
}

/// 図形の枠線太さ変更イベント
struct ShapeStrokeWidthChangedEvent: EditorEvent {
    var eventName = "ShapeStrokeWidthChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldWidth: CGFloat
    let newWidth: CGFloat
    
    var description: String {
        return "図形の枠線太さを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.strokeWidth = newWidth
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.strokeWidth = oldWidth
        }
    }
}

/// 図形の枠線モード変更イベント
struct ShapeStrokeModeChangedEvent: EditorEvent {
    var eventName = "ShapeStrokeModeChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldMode: StrokeMode
    let newMode: StrokeMode
    
    var description: String {
        return "図形の枠線モードを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.strokeMode = newMode
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.strokeMode = oldMode
        }
    }
}

/// 図形の角丸半径変更イベント
struct ShapeCornerRadiusChangedEvent: EditorEvent {
    var eventName = "ShapeCornerRadiusChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldRadius: CGFloat
    let newRadius: CGFloat
    
    var description: String {
        return "図形の角丸半径を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.cornerRadius = newRadius
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.cornerRadius = oldRadius
        }
    }
}

/// 図形の辺の数変更イベント
struct ShapeSidesChangedEvent: EditorEvent {
    var eventName = "ShapeSidesChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldSides: Int
    let newSides: Int
    
    var description: String {
        return "図形の辺の数を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.sides = newSides
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.sides = oldSides
        }
    }
}

/// 図形のグラデーション色変更イベント
struct ShapeGradientColorsChangedEvent: EditorEvent {
    let eventName = "ShapeGradientColorsChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldStartColor: UIColor
    let newStartColor: UIColor
    let oldEndColor: UIColor
    let newEndColor: UIColor
    
    var description: String {
        return "図形のグラデーション色を変更しました"
    }
    
    // Codable対応のためのプロパティ
    private enum CodingKeys: String, CodingKey {
        case timestamp, elementId
        case oldStartColorData, newStartColorData
        case oldEndColorData, newEndColorData
    }
    
    // カスタムエンコーダー
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(elementId, forKey: .elementId)
        
        // UIColorのエンコード
        let oldStartColorData = try NSKeyedArchiver.archivedData(withRootObject: oldStartColor, requiringSecureCoding: false)
        let newStartColorData = try NSKeyedArchiver.archivedData(withRootObject: newStartColor, requiringSecureCoding: false)
        let oldEndColorData = try NSKeyedArchiver.archivedData(withRootObject: oldEndColor, requiringSecureCoding: false)
        let newEndColorData = try NSKeyedArchiver.archivedData(withRootObject: newEndColor, requiringSecureCoding: false)
        
        try container.encode(oldStartColorData, forKey: .oldStartColorData)
        try container.encode(newStartColorData, forKey: .newStartColorData)
        try container.encode(oldEndColorData, forKey: .oldEndColorData)
        try container.encode(newEndColorData, forKey: .newEndColorData)
    }
    
    // カスタムデコーダー
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        elementId = try container.decode(UUID.self, forKey: .elementId)
        
        // UIColorのデコード
        let oldStartColorData = try container.decode(Data.self, forKey: .oldStartColorData)
        let newStartColorData = try container.decode(Data.self, forKey: .newStartColorData)
        let oldEndColorData = try container.decode(Data.self, forKey: .oldEndColorData)
        let newEndColorData = try container.decode(Data.self, forKey: .newEndColorData)
        
        guard let decodedOldStartColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: oldStartColorData),
              let decodedNewStartColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: newStartColorData),
              let decodedOldEndColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: oldEndColorData),
              let decodedNewEndColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: newEndColorData) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Failed to decode UIColor"
            ))
        }
        
        oldStartColor = decodedOldStartColor
        newStartColor = decodedNewStartColor
        oldEndColor = decodedOldEndColor
        newEndColor = decodedNewEndColor
    }
    
    // 通常のイニシャライザ
    init(elementId: UUID, oldStartColor: UIColor, newStartColor: UIColor, oldEndColor: UIColor, newEndColor: UIColor) {
        self.elementId = elementId
        self.oldStartColor = oldStartColor
        self.newStartColor = newStartColor
        self.oldEndColor = oldEndColor
        self.newEndColor = newEndColor
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.gradientStartColor = newStartColor
            element.gradientEndColor = newEndColor
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.gradientStartColor = oldStartColor
            element.gradientEndColor = oldEndColor
        }
    }
}

/// 図形のグラデーション角度変更イベント
struct ShapeGradientAngleChangedEvent: EditorEvent {
    var eventName = "ShapeGradientAngleChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldAngle: CGFloat
    let newAngle: CGFloat
    
    var description: String {
        return "図形のグラデーション角度を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.gradientAngle = newAngle
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ShapeElement {
            element.gradientAngle = oldAngle
        }
    }
}

// MARK: - 画像要素に関するイベントの実装

// fitMode 廃止: ImageFitModeChangedEvent 削除

/// 画像彩度変更イベント
struct ImageSaturationChangedEvent: EditorEvent {
    var eventName = "ImageSaturationChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldSaturation: CGFloat
    let newSaturation: CGFloat
    
    var description: String {
        return "画像の彩度を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.saturationAdjustment = newSaturation
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.saturationAdjustment = oldSaturation
        }
    }
}

/// 画像明度変更イベント
struct ImageBrightnessChangedEvent: EditorEvent {
    var eventName = "ImageBrightnessChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldBrightness: CGFloat
    let newBrightness: CGFloat
    
    var description: String {
        return "画像の明度を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.brightnessAdjustment = newBrightness
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.brightnessAdjustment = oldBrightness
        }
    }
}

/// 画像コントラスト変更イベント
struct ImageContrastChangedEvent: EditorEvent {
    var eventName = "ImageContrastChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldContrast: CGFloat
    let newContrast: CGFloat
    
    var description: String {
        return "画像のコントラストを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.contrastAdjustment = newContrast
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.contrastAdjustment = oldContrast
        }
    }
}

/// 画像ハイライト変更イベント
struct ImageHighlightsChangedEvent: EditorEvent {
    var eventName = "ImageHighlightsChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldHighlights: CGFloat
    let newHighlights: CGFloat
    
    var description: String {
        return "画像のハイライトを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.highlightsAdjustment = newHighlights
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.highlightsAdjustment = oldHighlights
        }
    }
}

/// 画像シャドウ変更イベント
struct ImageShadowsChangedEvent: EditorEvent {
    var eventName = "ImageShadowsChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldShadows: CGFloat
    let newShadows: CGFloat
    
    var description: String {
        return "画像のシャドウを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.shadowsAdjustment = newShadows
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.shadowsAdjustment = oldShadows
        }
    }
}

/// 画像色相変更イベント
struct ImageHueChangedEvent: EditorEvent {
    var eventName = "ImageHueChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldHue: CGFloat
    let newHue: CGFloat
    
    var description: String {
        return "画像の色相を変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.hueAdjustment = newHue
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.hueAdjustment = oldHue
        }
    }
}

/// 画像シャープネス変更イベント
struct ImageSharpnessChangedEvent: EditorEvent {
    var eventName = "ImageSharpnessChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldSharpness: CGFloat
    let newSharpness: CGFloat
    
    var description: String {
        return "画像のシャープネスを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.sharpnessAdjustment = newSharpness
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.sharpnessAdjustment = oldSharpness
        }
    }
}

/// 画像ガウシアンブラー変更イベント
struct ImageGaussianBlurChangedEvent: EditorEvent {
    var eventName = "ImageGaussianBlurChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldRadius: CGFloat
    let newRadius: CGFloat
    
    var description: String {
        return "画像のガウシアンブラーを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.gaussianBlurRadius = newRadius
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.gaussianBlurRadius = oldRadius
        }
    }
}

/// 画像ティントカラー変更イベント
struct ImageTintColorChangedEvent: EditorEvent {
    let eventName = "ImageTintColorChanged"
    var timestamp = Date()
    let elementId: UUID
    var oldColor: UIColor?
    var newColor: UIColor?
    let oldIntensity: CGFloat
    let newIntensity: CGFloat
    
    var description: String {
        return "画像のティントカラーを変更しました"
    }
    
    // Codable対応のためのプロパティ
    private enum CodingKeys: String, CodingKey {
        case timestamp, elementId, oldIntensity, newIntensity
        case oldColorData, newColorData
        case hasOldColor, hasNewColor
    }
    
    // カスタムエンコーダー
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(elementId, forKey: .elementId)
        try container.encode(oldIntensity, forKey: .oldIntensity)
        try container.encode(newIntensity, forKey: .newIntensity)
        
        // UIColorのエンコード（nilの場合も考慮）
        try container.encode(oldColor != nil, forKey: .hasOldColor)
        try container.encode(newColor != nil, forKey: .hasNewColor)
        
        if let oldColor = oldColor {
            let oldColorData = try NSKeyedArchiver.archivedData(withRootObject: oldColor, requiringSecureCoding: false)
            try container.encode(oldColorData, forKey: .oldColorData)
        }
        
        if let newColor = newColor {
            let newColorData = try NSKeyedArchiver.archivedData(withRootObject: newColor, requiringSecureCoding: false)
            try container.encode(newColorData, forKey: .newColorData)
        }
    }
    
    // カスタムデコーダー
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        elementId = try container.decode(UUID.self, forKey: .elementId)
        oldIntensity = try container.decode(CGFloat.self, forKey: .oldIntensity)
        newIntensity = try container.decode(CGFloat.self, forKey: .newIntensity)
        
        // UIColorのデコード（nilの場合も考慮）
        let hasOldColor = try container.decode(Bool.self, forKey: .hasOldColor)
        let hasNewColor = try container.decode(Bool.self, forKey: .hasNewColor)
        
        oldColor = nil
        newColor = nil
        
        if hasOldColor {
            let oldColorData = try container.decode(Data.self, forKey: .oldColorData)
            oldColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: oldColorData)
        }
        
        if hasNewColor {
            let newColorData = try container.decode(Data.self, forKey: .newColorData)
            newColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: newColorData)
        }
    }
    
    // 通常のイニシャライザ
    init(elementId: UUID, oldColor: UIColor?, newColor: UIColor?, oldIntensity: CGFloat, newIntensity: CGFloat) {
        self.elementId = elementId
        self.oldColor = oldColor
        self.newColor = newColor
        self.oldIntensity = oldIntensity
        self.newIntensity = newIntensity
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.tintColor = newColor
            element.tintIntensity = newIntensity
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.tintColor = oldColor
            element.tintIntensity = oldIntensity
        }
    }
}

/// 画像フレーム表示変更イベント
struct ImageShowFrameChangedEvent: EditorEvent {
    var eventName = "ImageShowFrameChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldValue: Bool
    let newValue: Bool
    
    var description: String {
        return "画像のフレーム表示を\(newValue ? "有効" : "無効")にしました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.showFrame = newValue
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.showFrame = oldValue
        }
    }
}

/// 画像フレーム色変更イベント
struct ImageFrameColorChangedEvent: EditorEvent {
    let eventName = "ImageFrameColorChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldColor: UIColor
    let newColor: UIColor
    
    var description: String {
        return "画像のフレーム色を変更しました"
    }
    
    // Codable対応のためのプロパティ
    private enum CodingKeys: String, CodingKey {
        case timestamp, elementId
        case oldColorData, newColorData
    }
    
    // カスタムエンコーダー
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(elementId, forKey: .elementId)
        
        // UIColorのエンコード
        let oldColorData = try NSKeyedArchiver.archivedData(withRootObject: oldColor, requiringSecureCoding: false)
        let newColorData = try NSKeyedArchiver.archivedData(withRootObject: newColor, requiringSecureCoding: false)
        
        try container.encode(oldColorData, forKey: .oldColorData)
        try container.encode(newColorData, forKey: .newColorData)
    }
    
    // カスタムデコーダー
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        elementId = try container.decode(UUID.self, forKey: .elementId)
        
        // UIColorのデコード
        let oldColorData = try container.decode(Data.self, forKey: .oldColorData)
        let newColorData = try container.decode(Data.self, forKey: .newColorData)
        
        guard let decodedOldColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: oldColorData),
              let decodedNewColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: newColorData) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Failed to decode UIColor"
            ))
        }
        
        oldColor = decodedOldColor
        newColor = decodedNewColor
    }
    
    // 通常のイニシャライザ
    init(elementId: UUID, oldColor: UIColor, newColor: UIColor) {
        self.elementId = elementId
        self.oldColor = oldColor
        self.newColor = newColor
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.frameColor = newColor
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.frameColor = oldColor
        }
    }
}

/// 画像フレーム太さ変更イベント
struct ImageFrameWidthChangedEvent: EditorEvent {
    var eventName = "ImageFrameWidthChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldWidth: CGFloat
    let newWidth: CGFloat
    
    var description: String {
        return "画像のフレーム太さを変更しました"
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.frameWidth = newWidth
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.frameWidth = oldWidth
        }
    }
}

/// 画像角丸設定変更イベント
struct ImageRoundedCornersChangedEvent: EditorEvent {
    var eventName = "ImageRoundedCornersChanged"
    var timestamp = Date()
    let elementId: UUID
    let wasRounded: Bool
    let isRounded: Bool
    let oldRadius: CGFloat
    let newRadius: CGFloat
    
    var description: String {
        if wasRounded != isRounded {
            return "画像の角丸を\(isRounded ? "有効" : "無効")にしました"
        } else {
            return "画像の角丸半径を変更しました"
        }
    }
    
    func apply(to project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.roundedCorners = isRounded
            element.cornerRadius = newRadius
        }
    }
    
    func revert(from project: LogoProject) {
        if let element = project.elements.first(where: { $0.id == elementId }) as? ImageElement {
            element.roundedCorners = wasRounded
            element.cornerRadius = oldRadius
        }
    }
}

// MARK: - その他

/// 背景設定変更イベント
struct BackgroundSettingsChangedEvent: EditorEvent {
    var eventName = "BackgroundSettingsChanged"
    var timestamp = Date()
    let oldSettings: BackgroundSettings
    let newSettings: BackgroundSettings
    
    var description: String {
        return "背景設定を変更しました"
    }
    
    func apply(to project: LogoProject) {
        project.backgroundSettings = newSettings
    }
    
    func revert(from project: LogoProject) {
        project.backgroundSettings = oldSettings
    }
}

/// プロジェクト名変更イベント
struct ProjectNameChangedEvent: EditorEvent {
    var eventName = "ProjectNameChanged"
    var timestamp = Date()
    let oldName: String
    let newName: String
    
    var description: String {
        return "プロジェクト名を「\(newName)」に変更しました"
    }
    
    func apply(to project: LogoProject) {
        project.name = newName
    }
    
    func revert(from project: LogoProject) {
        project.name = oldName
    }
}

/// キャンバスサイズ変更イベント
struct CanvasSizeChangedEvent: EditorEvent {
    var eventName = "CanvasSizeChanged"
    var timestamp = Date()
    let oldSize: CGSize
    let newSize: CGSize
    
    var description: String {
        return "キャンバスサイズを変更しました"
    }
    
    func apply(to project: LogoProject) {
        project.canvasSize = newSize
    }
    
    func revert(from project: LogoProject) {
        project.canvasSize = oldSize
    }
}

/// 要素の複合変更イベント（移動 + サイズ変更 + 回転）
struct ElementTransformedEvent: EditorEvent {
    var eventName = "ElementTransformed"
    var timestamp = Date()
    let elementId: UUID
    let oldPosition: CGPoint?
    let newPosition: CGPoint?
    let oldSize: CGSize?
    let newSize: CGSize?
    let oldRotation: CGFloat?
    let newRotation: CGFloat?
    
    var description: String {
        var desc = "要素を"
        if oldPosition != nil { desc += "移動" }
        if oldSize != nil { desc += oldPosition != nil ? "・リサイズ" : "リサイズ" }
        if oldRotation != nil { desc += (oldPosition != nil || oldSize != nil) ? "・回転" : "回転" }
        desc += "しました"
        return desc
    }
    
    func apply(to project: LogoProject) {
        guard let element = project.elements.first(where: { $0.id == elementId }) else { return }
        
        if let newPosition = newPosition {
            element.position = newPosition
        }
        
        if let newSize = newSize {
            element.size = newSize
        }
        
        if let newRotation = newRotation {
            element.rotation = newRotation
        }
    }
    
    func revert(from project: LogoProject) {
        guard let element = project.elements.first(where: { $0.id == elementId }) else { return }
        
        if let oldPosition = oldPosition {
            element.position = oldPosition
        }
        
        if let oldSize = oldSize {
            element.size = oldSize
        }
        
        if let oldRotation = oldRotation {
            element.rotation = oldRotation
        }
    }
}

/// 要素のZ-Index変更イベント
struct ElementZIndexChangedEvent: EditorEvent {
    var eventName = "ElementZIndexChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldZIndex: Int
    let newZIndex: Int
    
    var description: String {
        return "要素の描画順序を変更しました"
    }
    
    func apply(to project: LogoProject) {
        guard let element = project.elements.first(where: { $0.id == elementId }) else { return }
        element.zIndex = newZIndex
    }
    
    func revert(from project: LogoProject) {
        guard let element = project.elements.first(where: { $0.id == elementId }) else { return }
        element.zIndex = oldZIndex
    }
}
