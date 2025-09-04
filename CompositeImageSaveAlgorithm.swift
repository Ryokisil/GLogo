//
//  CompositeImageSaveAlgorithm.swift
//  GLogo - 画像・テキスト・図形統合保存アルゴリズム解説
//
//  概要:
//  このファイルは、GLogo アプリケーションで実装された画像保存時の
//  テキスト・図形要素統合機能の詳細な処理手順を説明します。
//  
//  主要機能:
//  1. 画像要素をベースとした統合画像生成
//  2. テキスト・図形要素の座標・サイズスケーリング
//  3. フォントサイズとエフェクトの比例調整
//  4. Z-Index順での正確なレイヤー合成
//

import UIKit
import Photos

// MARK: - メイン保存処理

/// 写真ライブラリへの保存処理
/// ユーザーがSaveボタンをタップした際に呼び出される
func performPhotoLibrarySave() {
    print("DEBUG: 写真ライブラリ保存開始")
    
    // STEP 1: プロジェクト内の全画像要素を取得
    // プロジェクトには複数の画像要素が存在する可能性があるため、全て抽出
    let imageElements = project.elements.compactMap { $0 as? ImageElement }
    print("DEBUG: 画像要素数: \(imageElements.count)")
    
    // STEP 2: 各画像要素について個別に保存処理を実行
    // 複数画像が存在する場合、それぞれに対してオーバーレイを適用
    for imageElement in imageElements {
        print("DEBUG: 画像要素 \(imageElement.id) の処理開始")
        
        // STEP 2.1: フィルター適用済み画像を取得
        // imageプロパティは既にフィルター（彩度、明度、コントラスト等）が適用された状態
        // 元画像(originalImage)ではなく、ユーザーが編集した最終状態を使用
        guard let processedImage = imageElement.image ?? imageElement.originalImage else {
            print("DEBUG: 画像の取得に失敗 - スキップ")
            continue  // この画像要素をスキップして次へ
        }
        
        print("DEBUG: 処理対象画像サイズ: \(processedImage.size)")
        
        // STEP 2.2: オーバーレイ要素（テキスト・図形）を抽出
        // 条件1: TextElement または ShapeElement のみ
        // 条件2: 可視状態（isVisible = true）のもののみ
        // 画像要素は除外（ベース画像として既に使用済み）
        let overlayElements = project.elements.filter { element in
            let isOverlayType = (element is TextElement || element is ShapeElement)
            let isVisible = element.isVisible
            print("DEBUG: 要素チェック \(element.type): オーバーレイ型=\(isOverlayType), 可視=\(isVisible)")
            return isOverlayType && isVisible
        }
        
        print("DEBUG: オーバーレイ要素数: \(overlayElements.count)")
        
        // STEP 2.3: 統合画像の生成
        var finalImage: UIImage
        
        if !overlayElements.isEmpty {
            // オーバーレイ要素が存在する場合 → 統合処理を実行
            print("DEBUG: オーバーレイ統合処理開始")
            finalImage = createCompositeImage(baseImage: processedImage, overlayElements: overlayElements) ?? processedImage
        } else {
            // オーバーレイ要素が無い場合 → 元画像をそのまま使用
            print("DEBUG: オーバーレイ要素なし - 元画像を使用")
            finalImage = processedImage
        }
        
        // STEP 2.4: Photo Library への保存実行
        print("DEBUG: Photo Library保存実行 - 最終画像サイズ: \(finalImage.size)")
        
        PHPhotoLibrary.shared().performChanges({
            // 画像アセット作成リクエストを発行
            // finalImage が Photos アプリに新規写真として保存される
            PHAssetChangeRequest.creationRequestForAsset(from: finalImage)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    print("DEBUG: 写真保存成功")
                    // UI更新: 保存完了通知
                } else {
                    print("DEBUG: 写真保存失敗: \(error?.localizedDescription ?? "不明なエラー")")
                    // UI更新: エラー通知
                }
            }
        })
    }
}

// MARK: - 統合画像生成アルゴリズム

/// 画像要素をベースにテキスト・図形要素を重ねた統合画像を作成
/// - Parameters:
///   - baseImage: ベース画像（フィルター適用済み）
///   - overlayElements: 重ねる要素配列（テキスト・図形）
/// - Returns: 統合された画像、失敗時はnil
private func createCompositeImage(baseImage: UIImage, overlayElements: [LogoElement]) -> UIImage? {
    print("DEBUG: createCompositeImage開始 - ベース画像サイズ: \(baseImage.size)")
    print("DEBUG: オーバーレイ要素数: \(overlayElements.count)")
    
    // STEP 1: 対象画像要素の特定
    // 保存する画像(baseImage)に対応するプロジェクト内の画像要素を検索
    // 座標変換の基準となるため、正確な特定が重要
    guard let targetImageElement = self.project.elements.first(where: { element in
        if let imageElement = element as? ImageElement,
           let originalImage = imageElement.originalImage {
            print("DEBUG: 画像要素候補 - オリジナル: \(originalImage.size), ベース: \(baseImage.size)")
            
            // サイズマッチング: 元画像サイズ または フィルター処理後画像サイズ
            // 両方チェックすることで、フィルター適用による微細なサイズ変更にも対応
            return originalImage.size == baseImage.size || imageElement.image?.size == baseImage.size
        }
        return false
    }) as? ImageElement else {
        // 対応する画像要素が見つからない場合のデバッグ情報出力
        print("DEBUG: 対象の画像要素が見つかりません")
        print("DEBUG: プロジェクト内の画像要素:")
        for element in project.elements {
            if let imageElement = element as? ImageElement {
                print("  - ID: \(imageElement.id), オリジナル: \(imageElement.originalImage?.size ?? .zero), 処理後: \(imageElement.image?.size ?? .zero)")
            }
        }
        return baseImage  // 統合処理を諦めて元画像を返す
    }
    
    // STEP 2: 描画コンテキストの設定
    // UIGraphicsImageRenderer: iOS 10以降の推奨画像生成方法
    // Core Graphics よりもメモリ効率が良く、自動的に適切な色空間を選択
    let imageSize = baseImage.size
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0      // スケール統一: Retina/非Retinaに関わらず1.0で統一
    format.opaque = true    // 不透明設定: 写真として保存するため透明度不要
    
    let renderer = UIGraphicsImageRenderer(size: imageSize, format: format)
    print("DEBUG: レンダラー設定完了 - 描画サイズ: \(imageSize)")
    
    // STEP 3: 統合描画実行
    return renderer.image { context in
        let cgContext = context.cgContext  // Core Graphics コンテキスト取得
        
        // STEP 3.1: ベース画像の描画（最下層）
        // 座標 (0,0) から描画 = 画像全体をキャンバスに配置
        baseImage.draw(at: .zero)
        print("DEBUG: ベース画像描画完了")
        
        // STEP 3.2: 座標変換パラメータの計算
        // キャンバス座標系（編集画面）から画像座標系（保存ファイル）への変換
        
        // 画像要素のキャンバス上での位置とサイズ
        let imageElementRect = CGRect(
            x: targetImageElement.position.x,      // キャンバス上のX座標
            y: targetImageElement.position.y,      // キャンバス上のY座標
            width: targetImageElement.size.width,  // キャンバス上での表示幅
            height: targetImageElement.size.height // キャンバス上での表示高
        )
        
        print("DEBUG: 画像要素の範囲: \(imageElementRect)")
        print("DEBUG: 保存画像サイズ: \(imageSize)")
        
        // スケール比率の計算
        // 実際の画像サイズ ÷ キャンバス上での表示サイズ = 拡大率
        let scaleX = imageSize.width / imageElementRect.width   // X軸方向の拡大率
        let scaleY = imageSize.height / imageElementRect.height // Y軸方向の拡大率
        print("DEBUG: 変換比率 - scaleX: \(scaleX), scaleY: \(scaleY)")
        
        // STEP 3.3: オーバーレイ要素の描画処理
        // Z-Index順（下から上へ）でソート: 重なり順序を正確に再現
        let sortedElements = overlayElements.sorted { $0.zIndex < $1.zIndex }
        print("DEBUG: Z-Index順ソート完了 - 要素数: \(sortedElements.count)")
        
        // 各要素について座標変換と描画を実行
        for element in sortedElements {
            print("DEBUG: ========== 要素 \(element.type) (ID: \(element.id)) ==========")
            
            // STEP 3.3.1: 境界検査
            // 要素が画像範囲と交差するかチェック（完全に範囲外の要素をスキップ）
            let elementRect = CGRect(x: element.position.x, y: element.position.y, width: element.size.width, height: element.size.height)
            
            guard imageElementRect.intersects(elementRect) else {
                print("DEBUG: 要素 \(element.type) は画像範囲外のためスキップ - 要素位置: \(elementRect)")
                continue  // この要素をスキップして次の要素へ
            }
            
            print("DEBUG: 要素境界チェック通過")
            print("  - キャンバス位置: \(element.position), サイズ: \(element.size)")
            print("  - 画像範囲との交差: \(imageElementRect.intersects(elementRect))")
            
            // STEP 3.3.2: 相対座標の計算
            // 画像要素に対する相対位置を 0.0〜1.0 の範囲で計算
            // この計算により、異なる解像度でも同じ相対位置に要素を配置可能
            
            let relativeX = (element.position.x - imageElementRect.minX) / imageElementRect.width
            let relativeY = (element.position.y - imageElementRect.minY) / imageElementRect.height
            let relativeWidth = element.size.width / imageElementRect.width
            let relativeHeight = element.size.height / imageElementRect.height
            
            print("DEBUG: 相対座標計算:")
            print("  - 相対位置: (\(relativeX), \(relativeY))")
            print("  - 相対サイズ: (\(relativeWidth), \(relativeHeight))")
            
            // STEP 3.3.3: 実座標への変換
            // 相対座標 × 実際の画像サイズ = 保存画像での実際の座標・サイズ
            let actualX = relativeX * imageSize.width
            let actualY = relativeY * imageSize.height
            let actualWidth = relativeWidth * imageSize.width
            let actualHeight = relativeHeight * imageSize.height
            
            print("DEBUG: 実座標変換:")
            print("  - 保存位置: (\(actualX), \(actualY))")
            print("  - 保存サイズ: (\(actualWidth), \(actualHeight))")
            
            // STEP 3.3.4: サイズ妥当性チェック
            // 0以下のサイズは描画エラーの原因となるため事前チェック
            guard actualWidth > 0 && actualHeight > 0 else {
                print("DEBUG: 無効なサイズのためスキップ")
                continue
            }
            
            // STEP 3.3.5: 要素のコピーと調整
            // 元要素を変更せず、描画用の調整済みコピーを作成
            let adjustedElement = element.copy()  // ディープコピー実行
            adjustedElement.position = CGPoint(x: actualX, y: actualY)           // 変換後座標を設定
            adjustedElement.size = CGSize(width: actualWidth, height: actualHeight) // 変換後サイズを設定
            
            // STEP 3.3.6: テキスト要素専用処理
            // フォントサイズとエフェクトパラメータのスケーリング
            if let textElement = adjustedElement as? TextElement {
                print("DEBUG: テキスト要素専用処理開始")
                
                // フォントサイズのスケーリング
                // 小さい方のスケール値を使用してアスペクト比を保持
                let originalFontSize = textElement.fontSize
                let scaledFontSize = originalFontSize * min(scaleX, scaleY)
                textElement.fontSize = scaledFontSize
                
                print("DEBUG: フォントサイズ調整:")
                print("  - 元サイズ: \(originalFontSize)pt -> スケール後: \(scaledFontSize)pt")
                
                // シャドウエフェクトのスケーリング
                for effect in textElement.effects {
                    if let shadowEffect = effect as? ShadowEffect {
                        print("DEBUG: シャドウエフェクト調整開始")
                        
                        // オフセットのスケーリング（X,Y個別に調整）
                        let originalOffset = shadowEffect.offset
                        shadowEffect.offset = CGSize(
                            width: originalOffset.width * scaleX,   // X軸オフセットをX軸スケールで調整
                            height: originalOffset.height * scaleY  // Y軸オフセットをY軸スケールで調整
                        )
                        
                        // ぼかし半径のスケーリング（アスペクト比保持）
                        let originalBlurRadius = shadowEffect.blurRadius
                        shadowEffect.blurRadius = originalBlurRadius * min(scaleX, scaleY)
                        
                        print("DEBUG: シャドウパラメータ調整:")
                        print("  - オフセット: \(originalOffset) -> \(shadowEffect.offset)")
                        print("  - ぼかし半径: \(originalBlurRadius) -> \(shadowEffect.blurRadius)")
                    }
                }
                
                print("DEBUG: テキスト要素詳細:")
                print("  - テキスト内容: '\(textElement.text)'")
                print("  - フォント名: \(textElement.fontName)")
                print("  - テキスト色: \(textElement.textColor)")
                print("  - エフェクト数: \(textElement.effects.count)")
            }
            
            // STEP 3.3.7: 描画実行
            print("DEBUG: 描画実行 - 調整後位置: \(adjustedElement.position), サイズ: \(adjustedElement.size)")
            print("DEBUG: 描画コンテキストサイズ: \(imageSize)")
            
            // 各要素の draw(in:) メソッドを呼び出し
            // - TextElement: NSAttributedString でテキスト描画（フォント、色、エフェクト適用）
            // - ShapeElement: Core Graphics でベクター図形描画（塗り、ストローク適用）
            adjustedElement.draw(in: cgContext)
            
            print("DEBUG: ========== 要素描画完了 ==========\n")
        }
        
        print("DEBUG: 全要素描画完了 - 統合画像生成成功")
    }
}

// MARK: - 技術的補足情報

/*
 === 座標系変換の数学的詳細 ===
 
 キャンバス座標系 → 画像座標系への変換式：
 
 相対位置 = (要素座標 - 画像要素座標) / 画像要素サイズ
 実座標 = 相対位置 × 実画像サイズ
 
 例：
 - 画像要素: 位置(100, 200), サイズ(300, 400) 【キャンバス上】
 - テキスト要素: 位置(150, 250) 【キャンバス上】
 - 実画像サイズ: 3000 × 4000px 【保存ファイル】
 
 計算：
 相対X = (150 - 100) / 300 = 0.167 (16.7%の位置)
 相対Y = (250 - 200) / 400 = 0.125 (12.5%の位置)
 
 実座標X = 0.167 × 3000 = 500px
 実座標Y = 0.125 × 4000 = 500px
 
 === スケーリング比率の重要性 ===
 
 scaleX = 実画像幅 / キャンバス表示幅
 scaleY = 実画像高 / キャンバス表示高
 
 この比率により：
 - フォントサイズ: min(scaleX, scaleY) で等比拡大
 - シャドウオフセット: X,Y個別にスケール適用
 - シャドウぼかし: min(scaleX, scaleY) でアスペクト比保持
 
 === メモリ効率化のポイント ===
 
 1. UIGraphicsImageRenderer 使用
    - 従来の UIGraphicsBeginImageContext より高効率
    - 自動的な色空間管理とメモリ管理
 
 2. 要素のコピーによる非破壊編集
    - 元要素は変更せず、描画用コピーのみ調整
    - Undo/Redo システムへの影響を回避
 
 3. 早期リターンによる無駄な処理の回避
    - 範囲外要素のスキップ
    - 無効サイズのチェック
    - 画像要素未検出時のフォールバック
 
 === Z-Index レイヤー管理 ===
 
 sortedElements = overlayElements.sorted { $0.zIndex < $1.zIndex }
 
 - 小さいzIndex → 大きいzIndex順で描画
 - 後から描画された要素が前面に表示
 - Photoshopのレイヤー順序と同じ概念
 
 === エラー耐性設計 ===
 
 1. guard文による早期リターン
 2. nil-coalescing (??) によるフォールバック
 3. 詳細なデバッグログによる問題診断支援
 4. 部分的失敗でも全体処理は継続
*/