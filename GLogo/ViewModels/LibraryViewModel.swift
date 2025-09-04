//
//  LibraryViewModel.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはロゴ作成用の要素ライブラリを管理するビューモデルを定義しています。
//  テンプレート、図形、テキストスタイル、背景、エフェクトなどのカテゴリに分類された
//  再利用可能なアイテムを提供します。ユーザーはライブラリからアイテムを選択して
//  プロジェクトに追加できます。また、カテゴリや検索テキストによるフィルタリング機能や
//  最近使用したアイテムの管理機能も実装しています。
//

import Foundation
import UIKit
import Combine

/// ライブラリカテゴリの種類
enum LibraryCategory: String, CaseIterable, Identifiable {
    case templates = "テンプレート"
    case shapes = "図形"
    case textStyles = "テキストスタイル"
    case backgrounds = "背景"
    case effects = "エフェクト"
    
    var id: String { self.rawValue }
    
    /// カテゴリアイコン名
    var iconName: String {
        switch self {
        case .templates: return "doc.on.doc"
        case .shapes: return "square.on.circle"
        case .textStyles: return "textformat"
        case .backgrounds: return "photo.fill"
        case .effects: return "sparkles"
        }
    }
}

/// ライブラリアイテムの基本プロトコル
protocol LibraryItem: Identifiable {
    var id: UUID { get }
    var name: String { get }
    var thumbnailImage: UIImage? { get }
    var category: LibraryCategory { get }
}

/// テンプレートアイテム
struct TemplateItem: LibraryItem {
    var id = UUID()
    var name: String
    var thumbnailImage: UIImage?
    var category: LibraryCategory { .templates }
    
    /// テンプレートのプロジェクト
    var project: LogoProject
}

/// 図形アイテム
struct ShapeItem: LibraryItem {
    var id = UUID()
    var name: String
    var thumbnailImage: UIImage?
    var category: LibraryCategory { .shapes }
    
    /// 図形のタイプ
    var shapeType: ShapeType
    
    /// 図形のパラメータ（オプション）
    var parameters: [String: Any]?
    
    /// 図形要素を作成
    func createShapeElement() -> ShapeElement {
        let element = ShapeElement(shapeType: shapeType)
        element.name = name
        
        // パラメータの適用（オプション）
        if let parameters = parameters {
            if let fillColor = parameters["fillColor"] as? UIColor {
                element.fillColor = fillColor
            }
            if let sides = parameters["sides"] as? Int {
                element.sides = sides
            }
            if let cornerRadius = parameters["cornerRadius"] as? CGFloat {
                element.cornerRadius = cornerRadius
            }
            // 他のパラメータも同様に設定
        }
        
        return element
    }
}

/// テキストスタイルアイテム
struct TextStyleItem: LibraryItem {
    var id = UUID()
    var name: String
    var thumbnailImage: UIImage?
    var category: LibraryCategory { .textStyles }
    
    /// フォント名
    var fontName: String
    
    /// フォントサイズ
    var fontSize: CGFloat
    
    /// テキストカラー
    var textColor: UIColor
    
    /// エフェクト
    var effects: [TextEffect]
    
    /// スタイルを適用したテキスト要素を作成
    func createTextElement(withText text: String = "サンプルテキスト") -> TextElement {
        let element = TextElement(text: text, fontName: fontName, fontSize: fontSize, textColor: textColor)
        element.name = name
        element.effects = effects
        return element
    }
    
    /// 既存のテキスト要素にスタイルを適用
    func applyStyle(to textElement: TextElement) {
        textElement.fontName = fontName
        textElement.fontSize = fontSize
        textElement.textColor = textColor
        textElement.effects = effects
    }
}

/// 背景アイテム
struct BackgroundItem: LibraryItem {
    var id = UUID()
    var name: String
    var thumbnailImage: UIImage?
    var category: LibraryCategory { .backgrounds }
    
    /// 背景設定
    var backgroundSettings: BackgroundSettings
}

/// エフェクトアイテム
struct EffectItem: LibraryItem {
    var id = UUID()
    var name: String
    var thumbnailImage: UIImage?
    var category: LibraryCategory { .effects }
    
    /// エフェクトのタイプ
    var effectType: TextEffectType
    
    /// エフェクトのパラメータ
    var parameters: [String: Any]
    
    /// テキストエフェクトを作成
    func createTextEffect() -> TextEffect? {
        switch effectType {
        case .shadow:
            let color = parameters["color"] as? UIColor ?? .black
            let offsetWidth = parameters["offsetWidth"] as? CGFloat ?? 2.0
            let offsetHeight = parameters["offsetHeight"] as? CGFloat ?? 2.0
            let blurRadius = parameters["blurRadius"] as? CGFloat ?? 3.0
            
            let effect = ShadowEffect(
                color: color,
                offset: CGSize(width: offsetWidth, height: offsetHeight),
                blurRadius: blurRadius
            )
            return effect
            
        case .stroke, .gradient, .glow:
            // 他のエフェクトタイプも同様に実装
            // 現在は未実装なのでnil
            return nil
        }
    }
}

/// ライブラリビューモデル - 要素ライブラリを管理
@MainActor
class LibraryViewModel: ObservableObject {
    // MARK: - プロパティ
    
    /// エディタビューモデル参照
    private weak var editorViewModel: EditorViewModel?
    
    /// 現在選択されているカテゴリ
    @Published var selectedCategory: LibraryCategory = .templates
    
    /// 検索テキスト
    @Published var searchText = ""
    
    /// すべてのライブラリアイテム
    @Published private(set) var allItems: [any LibraryItem] = []
    
    /// フィルタリングされたアイテム
    @Published private(set) var filteredItems: [any LibraryItem] = []
    
    /// 最近使用したアイテム
    @Published private(set) var recentItems: [any LibraryItem] = []
    
    // MARK: - イニシャライザ
    
    init(editorViewModel: EditorViewModel? = nil) {
        self.editorViewModel = editorViewModel
        
        // ライブラリアイテムの初期化
        loadLibraryItems()
        
        // フィルタリング
        filterItems()
    }
    
    // MARK: - メソッド
    
    /// ライブラリアイテムの読み込み
    private func loadLibraryItems() {
        var items: [any LibraryItem] = []
        
        // テンプレートアイテムの読み込み
        items.append(contentsOf: loadTemplates())
        
        // 図形アイテムの読み込み
        items.append(contentsOf: loadShapes())
        
        // テキストスタイルアイテムの読み込み
        items.append(contentsOf: loadTextStyles())
        
        // 背景アイテムの読み込み
        items.append(contentsOf: loadBackgrounds())
        
        // エフェクトアイテムの読み込み
        items.append(contentsOf: loadEffects())
        
        allItems = items
        filterItems()
    }
    
    /// テンプレートの読み込み
    private func loadTemplates() -> [TemplateItem] {
        // ここではダミーデータを返します
        // 実際のアプリでは、テンプレートファイルから読み込むか、
        // アセットから生成するなどの処理が必要です
        let templates: [TemplateItem] = [
            TemplateItem(
                name: "シンプルロゴ",
                thumbnailImage: UIImage(systemName: "circle"),
                project: LogoProject(name: "シンプルロゴ")
            ),
            TemplateItem(
                name: "ゲームロゴ",
                thumbnailImage: UIImage(systemName: "gamecontroller"),
                project: LogoProject(name: "ゲームロゴ")
            ),
            TemplateItem(
                name: "グラデーション",
                thumbnailImage: UIImage(systemName: "rays"),
                project: LogoProject(name: "グラデーション")
            )
        ]
        
        return templates
    }
    
    /// 図形の読み込み
    private func loadShapes() -> [ShapeItem] {
        // 基本図形
        let shapes: [ShapeItem] = [
            ShapeItem(
                name: "四角形",
                thumbnailImage: UIImage(systemName: "square"),
                shapeType: .rectangle
            ),
            ShapeItem(
                name: "角丸四角形",
                thumbnailImage: UIImage(systemName: "square.rounded"),
                shapeType: .roundedRectangle,
                parameters: ["cornerRadius": 10.0]
            ),
            ShapeItem(
                name: "円",
                thumbnailImage: UIImage(systemName: "circle"),
                shapeType: .circle
            ),
            ShapeItem(
                name: "楕円",
                thumbnailImage: UIImage(systemName: "oval"),
                shapeType: .ellipse
            ),
            ShapeItem(
                name: "三角形",
                thumbnailImage: UIImage(systemName: "triangle"),
                shapeType: .triangle
            ),
            ShapeItem(
                name: "五角形",
                thumbnailImage: UIImage(systemName: "pentagon"),
                shapeType: .polygon,
                parameters: ["sides": 5]
            ),
            ShapeItem(
                name: "六角形",
                thumbnailImage: UIImage(systemName: "hexagon"),
                shapeType: .polygon,
                parameters: ["sides": 6]
            ),
            ShapeItem(
                name: "星",
                thumbnailImage: UIImage(systemName: "star"),
                shapeType: .star,
                parameters: ["sides": 5]
            )
        ]
        
        return shapes
    }
    
    /// テキストスタイルの読み込み
    private func loadTextStyles() -> [TextStyleItem] {
        // 基本テキストスタイル
        let styles: [TextStyleItem] = [
            TextStyleItem(
                name: "基本",
                thumbnailImage: UIImage(systemName: "textformat"),
                fontName: "HelveticaNeue",
                fontSize: 36,
                textColor: .white,
                effects: []
            ),
            TextStyleItem(
                name: "タイトル",
                thumbnailImage: UIImage(systemName: "textformat.size"),
                fontName: "HelveticaNeue-Bold",
                fontSize: 48,
                textColor: .white,
                effects: [ShadowEffect()]
            ),
            TextStyleItem(
                name: "サブタイトル",
                thumbnailImage: UIImage(systemName: "textformat.alt"),
                fontName: "HelveticaNeue-Medium",
                fontSize: 24,
                textColor: .lightGray,
                effects: []
            ),
            TextStyleItem(
                name: "ゲームタイトル",
                thumbnailImage: UIImage(systemName: "gamecontroller"),
                fontName: "Impact",
                fontSize: 54,
                textColor: .orange,
                effects: [ShadowEffect(color: .black, offset: CGSize(width: 3, height: 3), blurRadius: 5)]
            )
        ]
        
        return styles
    }
    
    /// 背景の読み込み
    private func loadBackgrounds() -> [BackgroundItem] {
        // 基本背景
        let backgrounds: [BackgroundItem] = [
            BackgroundItem(
                name: "ソリッド黒",
                thumbnailImage: UIImage(systemName: "circle.fill"),
                backgroundSettings: BackgroundSettings(color: .black)
            ),
            BackgroundItem(
                name: "ソリッド白",
                thumbnailImage: UIImage(systemName: "circle"),
                backgroundSettings: BackgroundSettings(color: .white)
            ),
            BackgroundItem(
                name: "ブルーグラデーション",
                thumbnailImage: UIImage(systemName: "circle.righthalf.filled"),
                backgroundSettings: {
                    var settings = BackgroundSettings(startColor: .blue, endColor: .purple)
                    settings.type = .gradient
                    return settings
                }()
            )
        ]
        
        return backgrounds
    }
    
    /// エフェクトの読み込み
    private func loadEffects() -> [EffectItem] {
        // 基本エフェクト
        let effects: [EffectItem] = [
            EffectItem(
                name: "シャドウ",
                thumbnailImage: UIImage(systemName: "square.3.stack.3d"),
                effectType: .shadow,
                parameters: [
                    "color": UIColor.black,
                    "offsetWidth": 2.0,
                    "offsetHeight": 2.0,
                    "blurRadius": 3.0
                ]
            ),
            EffectItem(
                name: "ダークシャドウ",
                thumbnailImage: UIImage(systemName: "square.3.stack.3d.top.fill"),
                effectType: .shadow,
                parameters: [
                    "color": UIColor.black,
                    "offsetWidth": 4.0,
                    "offsetHeight": 4.0,
                    "blurRadius": 8.0
                ]
            )
        ]
        
        return effects
    }
    
    /// アイテムを検索語とカテゴリでフィルタリング
    func filterItems() {
        // 検索テキストが空で、カテゴリが選択されていない場合はすべてのアイテムを表示
        if searchText.isEmpty && selectedCategory == .templates {
            filteredItems = allItems
            return
        }
        
        // カテゴリでフィルタリング
        var filtered = allItems.filter { item in
            if selectedCategory == .templates {
                return true // すべてのカテゴリを表示
            } else {
                return item.category == selectedCategory
            }
        }
        
        // 検索テキストでフィルタリング
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.name.lowercased().contains(searchText.lowercased())
            }
        }
        
        filteredItems = filtered
    }
    
    /// 検索テキスト変更時のハンドラ
    func onSearchTextChanged() {
        filterItems()
    }
    
    /// カテゴリ選択時のハンドラ
    func onCategorySelected(_ category: LibraryCategory) {
        selectedCategory = category
        filterItems()
    }
    
    /// アイテム選択時のハンドラ
    func onItemSelected(_ item: any LibraryItem) {
        // 最近使用したアイテムに追加
        if !recentItems.contains(where: { $0.id == item.id }) {
            recentItems.insert(item, at: 0)
            
            // 最大10アイテムに制限
            if recentItems.count > 10 {
                recentItems.removeLast()
            }
        }
        
        // アイテムタイプに応じた処理
        if let editorViewModel = editorViewModel {
            switch item {
            case let templateItem as TemplateItem:
                // テンプレートを適用（新しいプロジェクトを作成）
                // 注意：これは現在のプロジェクトを上書きする
                // 実際のアプリでは確認ダイアログなどを表示する必要があります
                applyTemplate(templateItem)
                
            case let shapeItem as ShapeItem:
                // 図形を追加
                let shape = shapeItem.createShapeElement()
                addElementToCenter(shape)
                
            case let textStyleItem as TextStyleItem:
                // テキスト要素を追加、または選択中のテキスト要素にスタイルを適用
                applyTextStyle(textStyleItem)
                
            case let backgroundItem as BackgroundItem:
                // 背景を適用
                editorViewModel.updateBackgroundSettings(backgroundItem.backgroundSettings)
                
            case let effectItem as EffectItem:
                // エフェクトを適用（選択中のテキスト要素に適用）
                applyEffect(effectItem)
                
            default:
                break
            }
        }
    }
    
    /// テンプレートを適用
    private func applyTemplate(_ template: TemplateItem) {
        // 確認が必要なため、実際のアプリでは
        // プロジェクト変更の確認方法を提供する必要があります
    }
    
    /// 要素をキャンバスの中央に追加
    private func addElementToCenter(_ element: LogoElement) {
        guard let editorViewModel = editorViewModel else { return }
        
        // キャンバスサイズを取得
        let canvasSize = editorViewModel.project.canvasSize
        
        // 中央に配置
        element.position = CGPoint(
            x: (canvasSize.width - element.size.width) / 2,
            y: (canvasSize.height - element.size.height) / 2
        )
        
        // 要素を追加
        editorViewModel.addElement(element)
    }
    
    /// テキストスタイルを適用
    private func applyTextStyle(_ style: TextStyleItem) {
        guard let editorViewModel = editorViewModel else { return }
        
        if let selectedElement = editorViewModel.selectedElement as? TextElement {
            // 選択中のテキスト要素にスタイルを適用
            style.applyStyle(to: selectedElement)
            editorViewModel.updateTextElement(selectedElement)
        } else {
            // 新しいテキスト要素を作成
            let textElement = style.createTextElement()
            addElementToCenter(textElement)
        }
    }
    
    /// エフェクトを適用
    private func applyEffect(_ effectItem: EffectItem) {
        guard let editorViewModel = editorViewModel else { return }
        
        if let selectedElement = editorViewModel.selectedElement as? TextElement,
           let effect = effectItem.createTextEffect() {
            // 選択中のテキスト要素にエフェクトを適用
            selectedElement.effects.append(effect)
            editorViewModel.updateTextElement(selectedElement)
        }
    }
}
