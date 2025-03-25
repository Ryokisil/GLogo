////
////  EditorCommand.swift
////  GameLogoMaker
////
////  概要:
////  このファイルはエディタの操作コマンドを表すプロトコルと具体的な実装を定義します。
////  Commandパターンを使用してアンドゥ・リドゥ機能を実装するための基盤となります。
////  各コマンドは実行と元に戻す機能を持ち、エディタの操作履歴を効率的に管理します。
////
//
//import Foundation
//import UIKit
//
///// エディタコマンドを表すプロトコル
//protocol EditorCommand {
//    /// コマンドを実行
//    func execute()
//    
//    /// コマンドを元に戻す
//    func undo()
//}
//
//// MARK: - 要素操作コマンド
//
///// 要素追加コマンド
//class AddElementCommand: EditorCommand {
//    /// プロジェクト参照
//    private weak var project: LogoProject?
//    
//    /// 追加する要素
//    private let element: LogoElement
//    
//    /// イニシャライザ
//    init(project: LogoProject, element: LogoElement) {
//        self.project = project
//        self.element = element
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        project?.elements.append(element)
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        project?.elements.removeAll { $0.id == element.id }
//    }
//}
//
///// 要素削除コマンド
//class RemoveElementCommand: EditorCommand {
//    /// プロジェクト参照
//    private weak var project: LogoProject?
//    
//    /// 削除する要素
//    private let element: LogoElement
//    
//    /// 要素のインデックス（復元用）
//    private let index: Int
//    
//    /// イニシャライザ
//    init(project: LogoProject, element: LogoElement) {
//        self.project = project
//        self.element = element
//        
//        // 要素のインデックスを保存
//        if let index = project.elements.firstIndex(where: { $0.id == element.id }) {
//            self.index = index
//        } else {
//            self.index = project.elements.count
//        }
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        project?.elements.removeAll { $0.id == element.id }
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        guard let project = project else { return }
//        
//        // 元のインデックスに挿入（範囲チェック）
//        let safeIndex = min(index, project.elements.count)
//        project.elements.insert(element, at: safeIndex)
//    }
//}
//
///// 要素移動コマンド（改善版）
//class MoveElementCommand: EditorCommand {
//    /// プロジェクト参照
//    private let project: LogoProject
//    
//    /// 要素のID
//    private let elementId: UUID
//    
//    /// 元の位置
//    private let oldPosition: CGPoint
//    
//    /// 新しい位置
//    private let newPosition: CGPoint
//    
//    /// イニシャライザ
//    init(project: LogoProject, element: LogoElement, newPosition: CGPoint) {
//        self.project = project
//        self.elementId = element.id
//        self.oldPosition = element.position
//        self.newPosition = newPosition
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        if let element = findElement() {
//            element.position = newPosition
//        }
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        if let element = findElement() {
//            element.position = oldPosition
//        }
//    }
//    
//    /// 要素を検索
//    private func findElement() -> LogoElement? {
//        return project.elements.first(where: { $0.id == elementId })
//    }
//}
//
///// 要素サイズ変更コマンド（改善版）
//class ResizeElementCommand: EditorCommand {
//    /// プロジェクト参照
//    private let project: LogoProject
//    
//    /// 要素のID
//    private let elementId: UUID
//    
//    /// 元のサイズ
//    private let oldSize: CGSize
//    
//    /// 新しいサイズ
//    private let newSize: CGSize
//    
//    /// イニシャライザ
//    init(project: LogoProject, element: LogoElement, newSize: CGSize) {
//        self.project = project
//        self.elementId = element.id
//        self.oldSize = element.size
//        self.newSize = newSize
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        if let element = findElement() {
//            element.size = newSize
//        }
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        if let element = findElement() {
//            element.size = oldSize
//        }
//    }
//    
//    /// 要素を検索
//    private func findElement() -> LogoElement? {
//        return project.elements.first(where: { $0.id == elementId })
//    }
//}
//
///// 要素回転コマンド（改善版）
//class RotateElementCommand: EditorCommand {
//    /// プロジェクト参照
//    private let project: LogoProject
//    
//    /// 要素のID
//    private let elementId: UUID
//    
//    /// 元の回転角度
//    private let oldRotation: CGFloat
//    
//    /// 新しい回転角度
//    private let newRotation: CGFloat
//    
//    /// イニシャライザ
//    init(project: LogoProject, element: LogoElement, newRotation: CGFloat) {
//        self.project = project
//        self.elementId = element.id
//        self.oldRotation = element.rotation
//        self.newRotation = newRotation
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        if let element = findElement() {
//            element.rotation = newRotation
//        }
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        if let element = findElement() {
//            element.rotation = oldRotation
//        }
//    }
//    
//    /// 要素を検索
//    private func findElement() -> LogoElement? {
//        return project.elements.first(where: { $0.id == elementId })
//    }
//}
//
///// 要素の複数プロパティを一度に更新する複合コマンド
//class BatchElementUpdateCommand: EditorCommand {
//    /// プロジェクト参照
//    private let project: LogoProject
//    
//    /// 要素のID
//    private let elementId: UUID
//    
//    /// 元の要素のコピー
//    private let originalElement: LogoElement
//    
//    /// 新しい位置（変更がある場合のみ）
//    private let newPosition: CGPoint?
//    
//    /// 新しいサイズ（変更がある場合のみ）
//    private let newSize: CGSize?
//    
//    /// 新しい回転（変更がある場合のみ）
//    private let newRotation: CGFloat?
//    
//    /// イニシャライザ
//    init(project: LogoProject, element: LogoElement, newPosition: CGPoint? = nil, newSize: CGSize? = nil, newRotation: CGFloat? = nil) {
//        self.project = project
//        self.elementId = element.id
//        // 元の要素をディープコピー
//        self.originalElement = element.copy()
//        self.newPosition = newPosition
//        self.newSize = newSize
//        self.newRotation = newRotation
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        guard let index = findElementIndex() else { return }
//        
//        // 位置の更新
//        if let newPosition = newPosition {
//            project.elements[index].position = newPosition
//        }
//        
//        // サイズの更新
//        if let newSize = newSize {
//            project.elements[index].size = newSize
//        }
//        
//        // 回転の更新
//        if let newRotation = newRotation {
//            project.elements[index].rotation = newRotation
//        }
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        guard let index = findElementIndex() else { return }
//        
//        // 元の要素のコピーで置き換え
//        project.elements[index] = originalElement.copy()
//    }
//    
//    /// 要素のインデックスを検索
//    private func findElementIndex() -> Int? {
//        return project.elements.firstIndex(where: { $0.id == elementId })
//    }
//}
//
//// MARK: - テキスト要素コマンド
//
///// テキスト内容変更コマンド（改善版）
//class ChangeTextCommand: EditorCommand {
//    /// プロジェクト参照
//    private let project: LogoProject
//    
//    /// 要素のID
//    private let elementId: UUID
//    
//    /// 元のテキスト
//    private let oldText: String
//    
//    /// 新しいテキスト
//    private let newText: String
//    
//    /// イニシャライザ
//    init(project: LogoProject, textElement: TextElement, newText: String) {
//        self.project = project
//        self.elementId = textElement.id
//        self.oldText = textElement.text
//        self.newText = newText
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        if let textElement = findElement() as? TextElement {
//            textElement.text = newText
//        }
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        if let textElement = findElement() as? TextElement {
//            textElement.text = oldText
//        }
//    }
//    
//    /// 要素を検索
//    private func findElement() -> LogoElement? {
//        return project.elements.first(where: { $0.id == elementId })
//    }
//}
//
///// フォント変更コマンド（改善版）
//class ChangeFontCommand: EditorCommand {
//    /// プロジェクト参照
//    private let project: LogoProject
//    
//    /// 要素のID
//    private let elementId: UUID
//    
//    /// 元のフォント名
//    private let oldFontName: String
//    
//    /// 元のフォントサイズ
//    private let oldFontSize: CGFloat
//    
//    /// 新しいフォント名
//    private let newFontName: String
//    
//    /// 新しいフォントサイズ
//    private let newFontSize: CGFloat
//    
//    /// イニシャライザ
//    init(project: LogoProject, textElement: TextElement, newFontName: String, newFontSize: CGFloat) {
//        self.project = project
//        self.elementId = textElement.id
//        self.oldFontName = textElement.fontName
//        self.oldFontSize = textElement.fontSize
//        self.newFontName = newFontName
//        self.newFontSize = newFontSize
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        if let textElement = findElement() as? TextElement {
//            textElement.fontName = newFontName
//            textElement.fontSize = newFontSize
//        }
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        if let textElement = findElement() as? TextElement {
//            textElement.fontName = oldFontName
//            textElement.fontSize = oldFontSize
//        }
//    }
//    
//    /// 要素を検索
//    private func findElement() -> LogoElement? {
//        return project.elements.first(where: { $0.id == elementId })
//    }
//}
//
//// MARK: - 要素更新
//
///// 要素更新コマンド（改善版）
//class UpdateElementCommand: EditorCommand {
//    /// プロジェクト参照
//    private let project: LogoProject
//    
//    /// 要素のID（存在確認用）
//    private let elementId: UUID
//    
//    /// 古い要素のディープコピー
//    private let oldElementCopy: LogoElement
//    
//    /// 新しい要素のディープコピー
//    private let newElementCopy: LogoElement
//    
//    /// イニシャライザ
//    init(project: LogoProject, element: LogoElement, updatedElement: LogoElement) {
//        self.project = project
//        self.elementId = element.id
//        self.oldElementCopy = element.copy()
//        self.newElementCopy = updatedElement.copy()
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        if let index = project.elements.firstIndex(where: { $0.id == elementId }) {
//            project.elements[index] = newElementCopy.copy()
//        }
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        if let index = project.elements.firstIndex(where: { $0.id == elementId }) {
//            project.elements[index] = oldElementCopy.copy()
//        }
//    }
//}
//// MARK: - 図形要素コマンド
//
///// 図形タイプ変更コマンド
//class ChangeShapeTypeCommand: EditorCommand {
//    /// 図形要素
//    private weak var shapeElement: ShapeElement?
//    
//    /// 元の図形タイプ
//    private let oldShapeType: ShapeType
//    
//    /// 新しい図形タイプ
//    private let newShapeType: ShapeType
//    
//    /// イニシャライザ
//    init(shapeElement: ShapeElement, newShapeType: ShapeType) {
//        self.shapeElement = shapeElement
//        self.oldShapeType = shapeElement.shapeType
//        self.newShapeType = newShapeType
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        shapeElement?.shapeType = newShapeType
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        shapeElement?.shapeType = oldShapeType
//    }
//}
//
///// 塗りつぶし色変更コマンド
//class ChangeFillColorCommand: EditorCommand {
//    /// 図形要素
//    private weak var shapeElement: ShapeElement?
//    
//    /// 元の塗りつぶし色
//    private let oldFillColor: UIColor
//    
//    /// 新しい塗りつぶし色
//    private let newFillColor: UIColor
//    
//    /// イニシャライザ
//    init(shapeElement: ShapeElement, newFillColor: UIColor) {
//        self.shapeElement = shapeElement
//        self.oldFillColor = shapeElement.fillColor
//        self.newFillColor = newFillColor
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        shapeElement?.fillColor = newFillColor
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        shapeElement?.fillColor = oldFillColor
//    }
//}
//
//// MARK: - 画像要素コマンド
//
///// フィッティングモード変更コマンド
//class ChangeImageFitModeCommand: EditorCommand {
//    /// 画像要素
//    private weak var imageElement: ImageElement?
//    
//    /// 元のフィッティングモード
//    private let oldFitMode: ImageFitMode
//    
//    /// 新しいフィッティングモード
//    private let newFitMode: ImageFitMode
//    
//    /// イニシャライザ
//    init(imageElement: ImageElement, newFitMode: ImageFitMode) {
//        self.imageElement = imageElement
//        self.oldFitMode = imageElement.fitMode
//        self.newFitMode = newFitMode
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        imageElement?.fitMode = newFitMode
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        imageElement?.fitMode = oldFitMode
//    }
//}
//
//// MARK: - 背景設定コマンド
//
///// 背景設定変更コマンド
//class ChangeBackgroundSettingsCommand: EditorCommand {
//    /// プロジェクト参照
//    private weak var project: LogoProject?
//    
//    /// 元の背景設定
//    private let oldSettings: BackgroundSettings
//    
//    /// 新しい背景設定
//    private let newSettings: BackgroundSettings
//    
//    /// イニシャライザ
//    init(project: LogoProject, newSettings: BackgroundSettings) {
//        self.project = project
//        self.oldSettings = project.backgroundSettings
//        self.newSettings = newSettings
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        project?.backgroundSettings = newSettings
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        project?.backgroundSettings = oldSettings
//    }
//}
//
//// MARK: - 複合コマンド
//
///// 複数のコマンドをまとめて扱う複合コマンド（改善版）
//class CompositeCommand: EditorCommand {
//    /// コマンドリスト
//    private let commands: [EditorCommand]
//    
//    /// コマンド名（デバッグ用）
//    private let name: String
//    
//    /// イニシャライザ
//    init(commands: [EditorCommand], name: String = "複合コマンド") {
//        self.commands = commands
//        self.name = name
//    }
//    
//    /// すべてのコマンドを実行
//    func execute() {
//        for command in commands {
//            command.execute()
//        }
//    }
//    
//    /// すべてのコマンドを逆順に元に戻す
//    func undo() {
//        // 逆順で元に戻す
//        for command in commands.reversed() {
//            command.undo()
//        }
//    }
//    
//    /// デバッグ用の説明
//    var description: String {
//        return "\(name) (\(commands.count)個のコマンドを含む)"
//    }
//}
