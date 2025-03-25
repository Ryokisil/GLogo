//
//  UIFont+Extensions.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはUIFontクラスの拡張を提供します。
//  フォントの作成、サイズ調整、スタイル適用などの便利なメソッドやプロパティを追加し、
//  アプリ全体でのフォント管理をより簡単にします。
//

import UIKit

extension UIFont {
    
    // MARK: - スタイル変更
    
    /// フォントをボールドに変更
    func bold() -> UIFont {
        return withTraits(traits: .traitBold)
    }
    
    /// フォントをイタリックに変更
    func italic() -> UIFont {
        return withTraits(traits: .traitItalic)
    }
    
    /// 指定された特性を適用したフォントを返す
    private func withTraits(traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0) // サイズ0は現在のサイズを維持
    }
    
    /// フォントサイズを調整
    func withSize(_ size: CGFloat) -> UIFont {
        return UIFont(descriptor: fontDescriptor, size: size)
    }
    
    /// フォントウェイトを変更
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: 0) // サイズ0は現在のサイズを維持
    }
    
    // MARK: - フォント情報
    
    /// フォントがボールドかどうかを判定
    var isBold: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitBold)
    }
    
    /// フォントがイタリックかどうかを判定
    var isItalic: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
    
    /// フォントファミリー名を取得
    var familyName: String {
        return fontDescriptor.object(forKey: .family) as? String ?? ""
    }
    
    // MARK: - システムフォント
    
    /// ヘッドラインフォント
    static func headline(size: CGFloat = 17) -> UIFont {
        if #available(iOS 13.0, *) {
            return UIFont.systemFont(ofSize: size, weight: .semibold).withTraits(traits: [])
        } else {
            return UIFont.systemFont(ofSize: size, weight: .semibold)
        }
    }
    
    /// サブヘッドラインフォント
    static func subheadline(size: CGFloat = 15) -> UIFont {
        if #available(iOS 13.0, *) {
            return UIFont.systemFont(ofSize: size, weight: .medium).withTraits(traits: [])
        } else {
            return UIFont.systemFont(ofSize: size, weight: .medium)
        }
    }
    
    /// ボディテキストフォント
    static func body(size: CGFloat = 17) -> UIFont {
        return UIFont.systemFont(ofSize: size)
    }
    
    /// キャプションフォント
    static func caption(size: CGFloat = 12) -> UIFont {
        return UIFont.systemFont(ofSize: size, weight: .light)
    }
    
    // MARK: - フォント管理
    
    /// フォントファミリーに属するすべてのフォント名を取得
    static func fontNames(forFamily family: String) -> [String] {
        return UIFont.fontNames(forFamilyName: family)
    }
    
    /// 指定されたフォント名が有効かどうかを判定
    static func isValidFont(name: String) -> Bool {
        return UIFont(name: name, size: 12) != nil
    }
    
    /// システムで利用可能なすべてのフォントファミリーを取得し、辞書形式で返す
    static func getAllFonts() -> [String: [String]] {
        var result: [String: [String]] = [:]
        
        for family in UIFont.familyNames.sorted() {
            result[family] = UIFont.fontNames(forFamilyName: family).sorted()
        }
        
        return result
    }
    
    /// フォント名からフォントを安全に取得（失敗時はデフォルトフォントを返す）
    static func safeFont(name: String, size: CGFloat, defaultFont: UIFont? = nil) -> UIFont {
        if let font = UIFont(name: name, size: size) {
            return font
        }
        
        return defaultFont ?? UIFont.systemFont(ofSize: size)
    }
}

// MARK: - アプリフォント

extension UIFont {
    /// アプリで使用する共通フォント
    static let appFonts = AppFonts()
    
    /// アプリの共通フォントを定義する構造体
    struct AppFonts {
        // タイトル用
        func title(size: CGFloat = 24) -> UIFont {
            return UIFont.boldSystemFont(ofSize: size)
        }
        
        // 見出し用
        func heading(size: CGFloat = 18) -> UIFont {
            return UIFont.boldSystemFont(ofSize: size)
        }
        
        // 本文用
        func body(size: CGFloat = 16) -> UIFont {
            return UIFont.systemFont(ofSize: size)
        }
        
        // 強調用
        func emphasis(size: CGFloat = 16) -> UIFont {
            return UIFont.italicSystemFont(ofSize: size)
        }
        
        // 小さいテキスト用
        func small(size: CGFloat = 12) -> UIFont {
            return UIFont.systemFont(ofSize: size, weight: .light)
        }
        
        // ロゴフォント - デフォルトはヘルベチカ
        func logo(size: CGFloat = 36) -> UIFont {
            // 'Impact'フォントがインストールされていればそれを使用
            if let impactFont = UIFont(name: "Impact", size: size) {
                return impactFont
            }
            
            // AvantGardeがあればそれを使用（第2候補）
            if let avantGardeFont = UIFont(name: "AvantGarde-Bold", size: size) {
                return avantGardeFont
            }
            
            // デフォルトはヘルベチカ
            return UIFont.systemFont(ofSize: size, weight: .bold)
        }
        
        // ゲームテキスト用フォント
        func gameText(size: CGFloat = 24) -> UIFont {
            // ゲームっぽいフォントを優先順位で試す
            let gameStyleFonts = [
                "Futura-Bold",
                "Avenir-Black",
                "Verdana-Bold",
                "Arial-BoldMT"
            ]
            
            for fontName in gameStyleFonts {
                if let font = UIFont(name: fontName, size: size) {
                    return font
                }
            }
            
            // デフォルトはシステムボールド
            return UIFont.boldSystemFont(ofSize: size)
        }
    }
}
