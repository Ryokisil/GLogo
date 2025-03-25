////
////  EditorHistory.swift
////  GameLogoMaker
////
////  概要:
////  このファイルはエディタの操作履歴を管理するクラスを定義します。
////  EditorCommandを使用して、アンドゥ・リドゥ機能を効率的に実装し、
////  メモリ使用量を最適化しつつ、操作の履歴を管理します。
////
//
//import Foundation
//
///// エディタの操作履歴を管理するクラス
//class EditorHistory {
//    /// アンドゥ用のコマンドスタック
//    private var undoStack: [EditorCommand] = []
//    
//    /// リドゥ用のコマンドスタック
//    private var redoStack: [EditorCommand] = []
//    
//    /// 履歴の最大数
//    private let maxHistoryCount: Int
//    
//    /// プロジェクト参照
//    private(set) var project: LogoProject
//    
//    /// イニシャライザ
//    init(project: LogoProject, maxHistoryCount: Int = 100) {
//        self.project = project
//        self.maxHistoryCount = maxHistoryCount
//    }
//    
//    // MARK: - コマンド実行
//    
//    /// コマンドを実行して履歴に追加
//    func executeCommand(_ command: EditorCommand) {
//        command.execute()
//        undoStack.append(command)
//        
//        // 履歴の最大数を超えた場合、古いものから削除
//        if undoStack.count > maxHistoryCount {
//            undoStack.removeFirst()
//        }
//        
//        // リドゥスタックをクリア（新しい操作が行われた場合）
//        redoStack.removeAll()
//    }
//    
//    // MARK: - プロジェクト参照
//    
//    // プロジェクト参照を更新するメソッド
//    func updateProjectReference(_ project: LogoProject) {
//        self.project = project
//    }
//    
//    // MARK: - アンドゥ・リドゥ操作
//    
//    /// アンドゥ操作
//    @discardableResult
//    func undo() -> Bool {
//        // アンドゥスタックが空の場合は何もしない
//        guard let command = undoStack.popLast() else {
//            return false
//        }
//        
//        // コマンドを元に戻す
//        command.undo()
//        
//        // リドゥスタックに追加
//        redoStack.append(command)
//        
//        return true
//    }
//    
//    /// リドゥ操作
//    @discardableResult
//    func redo() -> Bool {
//        // リドゥスタックが空の場合は何もしない
//        guard let command = redoStack.popLast() else {
//            return false
//        }
//        
//        // コマンドを再実行
//        command.execute()
//        
//        // アンドゥスタックに追加
//        undoStack.append(command)
//        
//        return true
//    }
//    // MARK: - 状態チェック
//    
//    /// アンドゥ可能かどうか
//    var canUndo: Bool {
//        return !undoStack.isEmpty
//    }
//    
//    /// リドゥ可能かどうか
//    var canRedo: Bool {
//        return !redoStack.isEmpty
//    }
//    
//    // MARK: - 履歴管理
//    
//    /// 履歴をクリア
//    func clearHistory() {
//        undoStack.removeAll()
//        redoStack.removeAll()
//    }
//    
//    /// アンドゥスタックの深さ（履歴の数）
//    var undoCount: Int {
//        return undoStack.count
//    }
//    
//    /// リドゥスタックの深さ
//    var redoCount: Int {
//        return redoStack.count
//    }
//}
