////
////  追加のコマンド実装
////  GameLogoMaker
////
////  概要:
////  EditorCommandの追加実装クラスです。
////  EditorViewModel.swiftの変更内容で使用されているコマンドを定義しています。
////
//
//import Foundation
//import UIKit
//
//// MARK: - プロジェクト設定コマンド
//
///// プロジェクト名変更コマンド
//class ProjectNameChangeCommand: EditorCommand {
//    /// プロジェクト参照
//    private var project: LogoProject?
//    
//    /// 元のプロジェクト名
//    private let oldName: String
//    
//    /// 新しいプロジェクト名
//    private let newName: String
//    
//    /// イニシャライザ
//    init(project: LogoProject, newName: String) {
//        self.project = project
//        self.oldName = project.name
//        self.newName = newName
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        project?.name = newName
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        project?.name = oldName
//    }
//}
//
///// キャンバスサイズ変更コマンド
//class CanvasSizeChangeCommand: EditorCommand {
//    /// プロジェクト参照
//    private var project: LogoProject?
//    
//    /// 元のキャンバスサイズ
//    private let oldSize: CGSize
//    
//    /// 新しいキャンバスサイズ
//    private let newSize: CGSize
//    
//    /// イニシャライザ
//    init(project: LogoProject, newSize: CGSize) {
//        self.project = project
//        self.oldSize = project.canvasSize
//        self.newSize = newSize
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        project?.canvasSize = newSize
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        project?.canvasSize = oldSize
//    }
//}
//
//// MARK: - レイヤー操作コマンド
//
///// 要素を最前面に移動するコマンド
//class BringToFrontCommand: EditorCommand {
//    /// プロジェクト参照
//    private var project: LogoProject?
//    
//    /// 対象の要素
//    private let element: LogoElement
//    
//    /// 元のインデックス
//    private let originalIndex: Int
//    
//    /// イニシャライザ
//    init(project: LogoProject, element: LogoElement) {
//        self.project = project
//        self.element = element
//        
//        // 元のインデックスを保存
//        if let index = project.elements.firstIndex(where: { $0.id == element.id }) {
//            self.originalIndex = index
//        } else {
//            self.originalIndex = -1
//        }
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        guard let project = project, originalIndex >= 0 else { return }
//        
//        // 要素を一時的に削除
//        project.elements.removeAll { $0.id == element.id }
//        
//        // 最後（最前面）に追加
//        project.elements.append(element)
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        guard let project = project, originalIndex >= 0 else { return }
//        
//        // 要素を一時的に削除
//        project.elements.removeAll { $0.id == element.id }
//        
//        // 元の位置に戻す
//        if originalIndex < project.elements.count {
//            project.elements.insert(element, at: originalIndex)
//        } else {
//            project.elements.append(element)
//        }
//    }
//}
//
///// 要素を最背面に移動するコマンド
//class SendToBackCommand: EditorCommand {
//    /// プロジェクト参照
//    private var project: LogoProject?
//    
//    /// 対象の要素
//    private let element: LogoElement
//    
//    /// 元のインデックス
//    private let originalIndex: Int
//    
//    /// イニシャライザ
//    init(project: LogoProject, element: LogoElement) {
//        self.project = project
//        self.element = element
//        
//        // 元のインデックスを保存
//        if let index = project.elements.firstIndex(where: { $0.id == element.id }) {
//            self.originalIndex = index
//        } else {
//            self.originalIndex = -1
//        }
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        guard let project = project, originalIndex >= 0 else { return }
//        
//        // 要素を一時的に削除
//        project.elements.removeAll { $0.id == element.id }
//        
//        // 最初（最背面）に追加
//        project.elements.insert(element, at: 0)
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        guard let project = project, originalIndex >= 0 else { return }
//        
//        // 要素を一時的に削除
//        project.elements.removeAll { $0.id == element.id }
//        
//        // 元の位置に戻す
//        if originalIndex < project.elements.count {
//            project.elements.insert(element, at: originalIndex)
//        } else {
//            project.elements.append(element)
//        }
//    }
//}
//
//// MARK: - 要素プロパティコマンド
//
///// 要素の可視性を切り替えるコマンド
//class ToggleVisibilityCommand: EditorCommand {
//    /// 対象の要素
//    private weak var element: LogoElement?
//    
//    /// 元の可視性
//    private let originalVisibility: Bool
//    
//    /// イニシャライザ
//    init(element: LogoElement) {
//        self.element = element
//        self.originalVisibility = element.isVisible
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        element?.isVisible = !originalVisibility
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        element?.isVisible = originalVisibility
//    }
//}
//
///// 要素のロック状態を切り替えるコマンド
//class ToggleLockCommand: EditorCommand {
//    /// 対象の要素
//    private weak var element: LogoElement?
//    
//    /// 元のロック状態
//    private let originalLockState: Bool
//    
//    /// イニシャライザ
//    init(element: LogoElement) {
//        self.element = element
//        self.originalLockState = element.isLocked
//    }
//    
//    /// コマンドを実行
//    func execute() {
//        element?.isLocked = !originalLockState
//    }
//    
//    /// コマンドを元に戻す
//    func undo() {
//        element?.isLocked = originalLockState
//    }
//}
