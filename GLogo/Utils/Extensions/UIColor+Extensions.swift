//
//  UIColor+Extensions.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはUIColorクラスの拡張を提供します。
//  色の作成、変換、操作のための便利なメソッドやプロパティを追加し、
//  アプリ全体での色の扱いをより簡単にします。
//

import UIKit

extension UIColor {
    
    // MARK: - イニシャライザ
    
    /// RGB値から色を作成（0-255の整数値）＊色の強さは0から255の数字で表現。0 = 真っ暗（その色の光が全く無い）255 = 最大の明るさ（その色の光が最大）
    convenience init(r: Int, g: Int, b: Int, a: CGFloat = 1.0) {
        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: a
        )
    }
    
    /// 16進数の文字列から色を作成（例: "#FF5500" または "FF5500"）
    convenience init?(hex: String, alpha: CGFloat = 1.0) {
        // 前後の空白や改行を取り除く
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        // "#"を取り除く
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    /// HSB（色相、彩度、明度）値から色を作成
    convenience init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat = 1.0) {
        self.init(hue: hue / 360.0, saturation: saturation, brightness: brightness, alpha: alpha)
    }
    
    // MARK: - プロパティ
    
    /// RGB値を取得
    var rgbComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        if getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (r, g, b, a)
        }
        
        // sRGBカラースペースに変換して再試行
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        if let srgbColor = self.cgColor.converted(to: colorSpace!, intent: .defaultIntent, options: nil) {
            let uiColor = UIColor(cgColor: srgbColor)
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        }
        
        return (r, g, b, a)
    }
    
    /// HSB値を取得
    var hsbComponents: (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        if getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return (h, s, b, a)
        }
        
        // sRGBカラースペースに変換して再試行
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        if let srgbColor = self.cgColor.converted(to: colorSpace!, intent: .defaultIntent, options: nil) {
            let uiColor = UIColor(cgColor: srgbColor)
            uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        }
        
        return (h, s, b, a)
    }
    
    /// 16進数の文字列表現を取得（例: "#FF5500"）
    var hexString: String {
        let components = rgbComponents
        let r = Int(components.red * 255.0)
        let g = Int(components.green * 255.0)
        let b = Int(components.blue * 255.0)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    /// 色の明度を計算（0.0〜1.0）
    var brightness: CGFloat {
        let components = rgbComponents
        // 人間の目の感度に基づいた輝度の計算: Y = 0.2126 R + 0.7152 G + 0.0722 B
        return 0.2126 * components.red + 0.7152 * components.green + 0.0722 * components.blue
    }
    
    /// 色が明るいか暗いかを判定
    var isDark: Bool {
        return brightness < 0.5
    }
    
    /// 色が明るいか暗いかに基づいて、白または黒を返す（テキストの色に最適）
    var contrastingColor: UIColor {
        return isDark ? .white : .black
    }
    
    // MARK: - メソッド
    
    /// 色を指定された量だけ明るくする
    func lighter(by amount: CGFloat = 0.2) -> UIColor {
        return adjustBrightness(by: amount)
    }
    
    /// 色を指定された量だけ暗くする
    func darker(by amount: CGFloat = 0.2) -> UIColor {
        return adjustBrightness(by: -amount)
    }
    
    /// 明度を調整する内部メソッド
    private func adjustBrightness(by amount: CGFloat) -> UIColor {
        let components = hsbComponents
        return UIColor(
            hue: components.hue,
            saturation: components.saturation,
            brightness: max(0, min(1, components.brightness + amount)),
            alpha: components.alpha
        )
    }
    
    /// 彩度を調整
    func adjustSaturation(by amount: CGFloat) -> UIColor {
        let components = hsbComponents
        return UIColor(
            hue: components.hue,
            saturation: max(0, min(1, components.saturation + amount)),
            brightness: components.brightness,
            alpha: components.alpha
        )
    }
    
    /// 2つの色を指定された比率で混合
    static func blend(_ color1: UIColor, with color2: UIColor, ratio: CGFloat) -> UIColor {
        let ratio = max(0, min(1, ratio)) // 0〜1の範囲に制限
        
        let components1 = color1.rgbComponents
        let components2 = color2.rgbComponents
        
        return UIColor(
            red: components1.red * (1 - ratio) + components2.red * ratio,
            green: components1.green * (1 - ratio) + components2.green * ratio,
            blue: components1.blue * (1 - ratio) + components2.blue * ratio,
            alpha: components1.alpha * (1 - ratio) + components2.alpha * ratio
        )
    }
    
    /// ランダムな色を生成
    static func random(alpha: CGFloat = 1.0) -> UIColor {
        return UIColor(
            red: CGFloat.random(in: 0...1),
            green: CGFloat.random(in: 0...1),
            blue: CGFloat.random(in: 0...1),
            alpha: alpha
        )
    }
    
    /// グラデーション色の配列を生成
    static func gradient(from startColor: UIColor, to endColor: UIColor, steps: Int) -> [UIColor] {
        var gradientColors: [UIColor] = []
        
        for step in 0..<steps {
            let ratio = CGFloat(step) / CGFloat(max(1, steps - 1))
            gradientColors.append(blend(startColor, with: endColor, ratio: ratio))
        }
        
        return gradientColors
    }
    
    /// UIColorからCGColorに安全に変換（nil対応）
    func cgColor(default defaultColor: UIColor = .black) -> CGColor {
        return self.cgColor
    }
}

// MARK: - 色定数

extension UIColor {
    /// アプリで使用する共通色
    static let appColors = AppColors()
    
    /// アプリの共通色を定義する構造体
    struct AppColors {
        // ブランドカラー
        let primary = UIColor(hex: "#3498DB")!
        let secondary = UIColor(hex: "#2ECC71")!
        let accent = UIColor(hex: "#F39C12")!
        
        // テキストカラー
        let textPrimary = UIColor.black
        let textSecondary = UIColor.darkGray
        let textTertiary = UIColor.gray
        
        // バックグラウンドカラー
        let background = UIColor.white
        let backgroundSecondary = UIColor(hex: "#F5F5F5")!
        
        // 機能色
        let success = UIColor(hex: "#27AE60")!
        let warning = UIColor(hex: "#E67E22")!
        let error = UIColor(hex: "#E74C3C")!
        let info = UIColor(hex: "#3498DB")!
    }
}
