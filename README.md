# 概要
GLogoは画像編集用のiOSアプリケーションです。

## 技術情報 アーキテクチャ MVVM + Clean Architecture
- **Views**: SwiftUIベースのユーザーインターフェース（表示と操作の入口）
- **ViewModels**: 画面状態と操作のオーケストレーション（UIロジック）
- **UseCases**: インポート/保存/描画などのビジネスルール
- **Models**: ロゴプロジェクト、要素（テキスト、図形、画像）、背景設定などのデータモデル
- **Utils**: 画像処理やヘルパー（再利用可能な処理群）

### 言語: Swift 6.0
- UI Framework: SwiftUI + UIKit
- グラフィックス: Core Graphics, Core Image
- イベント処理: イベントソーシングパターンによるUndoとRedo
- 非同期処理: Swift Concurrency (async/await)

## 非機能要件（パフォーマンス）
- 目的: 画像編集で「待たせない」体感を最優先にする
- 計測条件: Releaseビルド、実機、4K画像（HEIC/PNG）、要素数1〜3
- 起動: コールド<=2.5s / ウォーム<=1.2s（編集可能になるまで）
- インポート: 4Kプレビュー<=300ms（低解像度を即時表示）、フル品質反映<=1.5s
- 編集: スライダー変更→プレビュー<=100ms、ドラッグは55〜60fps維持
- 保存: 4K<=2.5s、8K<=6s（2s超は進捗/キャンセル表示）
- 実測: iPhone 16で起動計測の平均2.243s（5回測定）。数値は妥当な水準で、KPI範囲内。iPhone X相当は未検証。
- 実測: iPhone 16でインポート（4K HEIC→プレビュー）平均0.314s（5回測定）。
- 実測: iPhone 16で保存処理（フィルター適用+HEICエンコード）平均0.535s（5回測定）。
- 注記: テスト生成画像はrendererのscale依存で実ピクセルは11520x6480（3x）。4Kぴったりで測る場合はscale=1.0で再計測する。

# フィルターの詳細
- ルミナンスマスクベースのセレクティブ調整: 標準のCore Imageフィルターでは実現できないハイライトとシャドウの実装。RGB→輝度変換にITU-R BT.709規格の係数（R: 0.2126, G: 0.7152, B: 0.0722）を採用し、人間の視覚特性に基づいた自然な調整を実現。
備考：ITU-R BT.709（通称Rec.709）は国際電気通信連合（ITU）により制定されたHDTV（高精細テレビ）向けの映像フォーマット標準で、デジタル映像業界では非常に有名かつ広く採用されている規格。
- マルチパスフィルタリング: 複数のフィルターを段階的に適用することで複雑な効果を実現。例えば、ハイライト調整では輝度抽出→ガンマ補正→露出調整→マスクブレンドの4段階の処理を実装。
- 合成処理の最適化: **CIBlendWithMask**

# トーンカーブの明るさずれとパフォーマンス対策
- 症状: 編集直後のプレビューだけ明るく見える（保存結果は正しい）。
- 原因: 非編集中の描画でフィルターを再適用しており、トーンカーブが二重に掛かっていた（`ImageElement.draw(in:)`で`applyFilters`を再実行）。
- 対策: 非編集時はフィルター済み画像をそのまま描画し、編集中のみプレビュー品質（軽量LUT）で単回適用。同期/非同期とも品質フラグ（preview/full）を揃えて二重適用を防止。

# フィルター処理フローの整理（Before/After）
- Before:
  - `ImageElement`内でフィルター適用を直接実行。プレビュー時にリサイズ（最大384px）＋LUT16³、フルは原寸＋LUT64³。
  - プレビューキャッシュキーがトーンカーブのみで、他の調整（明るさ等）が変わると古いプレビューが返ることがあった。
  - トーンカーブ・ガウシアン最終処理をタイマーでデバウンス。
- After:
  - レンダリング基盤（`Utils/Rendering/RenderPolicy`, `RenderContext`, `FilterPipeline`, `AdjustmentStages`, `ToneCurveStage`, `PreviewCache`, `RenderScheduler`）を追加し、`ImageElement`はパラメータを渡すだけに整理。
  - プレビューでも原寸でフィルターを適用（リサイズなし）。LUTはpreview=16³, full=64³を維持。
  - プレビューキャッシュキーをトーンカーブ＋全調整値のハッシュに拡張し、古いプレビューが返らないように改善。
  - トーンカーブ・ガウシアンの最終品質処理は`RenderScheduler`で最新のみ実行（旧タイマー削除）。

# ハイライト&シャドウの実装詳細
Core Imageには直接これらを操作するための標準フィルターが存在しない為、複数のフィルターを組み合わせて独自に実装。
**ハイライト調整は画像の明るい部分のみを選択的に調整するための機能です。**

## 1.前処理と入力値の検証

- 調整量が0の場合は処理をスキップして元画像を返す（最適化）
- 調整量を-1.0〜1.0の範囲に制限して予測可能な動作を確保


## 2.ルミナンスマスクの作成

- CIColorMatrixフィルターを使用して画像をグレースケールに変換
- RGB→輝度変換にITU-R BT.709規格の係数(R:0.2126, G:0.7152, B:0.0722)を使用
- この係数は人間の視覚特性（緑に最も敏感）に基づいている


## 3.暗くする場合と明るくする場合で処理を分岐
a. ハイライトを暗くする場合:

- ガンマ補正（CIGammaAdjust）を適用し明るい部分を強調したマスクを作成
- CIExposureAdjustで露出を下げる（負のEV値を設定）
- CIBlendWithMaskでマスクを使って元画像と調整画像をブレンド

b. ハイライトを明るくする場合:

- 同様にガンマ補正でマスクを作成
- CIExposureAdjustで露出を上げる（正のEV値を設定）
- CIBlendWithMaskでマスクを使って元画像と調整画像をブレンド


## 4.マスクによる部分的な適用

- マスクの明るさに応じて元画像と調整画像を合成
- これにより画像の明るい部分のみが調整され、暗い部分は元のまま保持される


# シャドウ調整の実装
**シャドウ調整は画像の暗い部分だけを部分的に調整するための機能です。**

## 前処理と入力値の検証

- 調整量が0の場合は処理をスキップ
- 調整量を-1.0〜1.0の範囲に制限


## 暗くする場合と明るくする場合で処理を分岐
a. シャドウを暗くする場合:

- CIColorControlsでコントラストを増加させ、明るさを微減
- CIColorMatrixで輝度マスクを生成（暗い部分を検出）
- CIGammaAdjustでガンマ値を大きくし暗い部分を強調したマスクを作成
- CIBlendWithMaskでマスクを使って元画像と調整画像をブレンド

b. シャドウを明るくする場合:

- CIColorControlsで明るさを増加
- CIColorMatrixで輝度マスクを生成
- CIColorInvertでマスクを反転し、暗い部分を強調
- CIGammaAdjustでさらに中間〜暗い部分を強調
- CIBlendWithMaskでマスクを使って元画像と調整画像をブレンド

**編集前**
<img src="./images/スクショ1.png" alt="調整前" width="250">

**ハイライト編集後**
<img src="./images/スクショ2.png" alt="ハイライト調整後" width="250">

**ハイライト&シャドウ編集後**
<img src="./images/スクショ3.png" alt="ハイライト&シャドウ調整後" width="250">


# 画像クロップ処理の問題（iOS向き対応）
## 問題の概要
縦長の特定サイズ画像（例：4284×5712、1178×1572）をクロップすると、結果の幅と高さが逆転してしまう。

## 原因分析
iOS画像処理の構造的な問題
iOSにおける画像処理には、以下の2つの重要な概念があります：
- 1 UIImage: 表示時の向き情報（orientation）を含む画像オブジェクト
- 2 CGImage: 実際のピクセル配列のみを持つ低レベルな画像オブジェクト
例：縦長画像の場合
UIImage.size = (幅: 1178, 高さ: 1572)  ← 表示時のサイズ
CGImage.size = (幅: 1572, 高さ: 1178)  ← 物理的なピクセル配列

## 具体的な不具合のメカニズム
1 クロップ処理ではUIImage.sizeを基準に座標計算を実行
2 実際のクロップはCGImageに対して実行
3 向き情報が反映されていないため、サイズが逆転した状態でクロップが発生

### 向きを考慮したCGImageの生成

```swift
/// UIImageの向き情報を考慮したCGImageを生成する
/// - Parameter uiImage: 向き情報を持つ元のUIImage
/// - Returns: UIImageの表示サイズと一致するCGImage
/// 
/// なぜ必要か：
/// iOSではUIImageとCGImageで画像の向きの扱いが異なる
/// - UIImage: orientation情報を持ち、表示時に自動的に向きを調整
/// - CGImage: 実際のピクセル配列のみを持ち、向き情報を持たない
/// 
/// 例：縦長写真の場合
/// - UIImage.size = (幅: 1178, 高さ: 1572) ← ユーザーが見ている向き
/// - CGImage.size = (幅: 1572, 高さ: 1178) ← 実際のピクセル配列
/// 
/// この不一致により、UIImageの座標系でクロップ範囲を計算しても、
/// CGImageに直接適用すると90度回転した位置をクロップしてしまう
private func createOrientedCGImage(from uiImage: UIImage) -> CGImage? {
    // UIImageの表示サイズを取得（向きが考慮されたサイズ）
    let size = uiImage.size
    
    // レンダラーの設定を準備
    let format = UIGraphicsImageRendererFormat()
    format.scale = uiImage.scale  // Retinaディスプレイ対応のため元画像のscaleを維持
    format.opaque = false         // 透明度を保持（PNG画像などに対応）
    
    // UIGraphicsImageRendererを使用する理由：
    // このAPIは自動的にUIImageのorientation情報を考慮して描画するため、
    // 生成されるCGImageはUIImageの表示サイズと一致する
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    
    // 向きを考慮した新しい画像を生成
    let renderedImage = renderer.image { context in
        // drawメソッドは自動的にorientation情報を適用して描画
        uiImage.draw(in: CGRect(origin: .zero, size: size))
    }
    
    // この時点でCGImageのサイズはUIImageの表示サイズと一致している
    return renderedImage.cgImage
}
```

### クロップ処理

```swift
private func cropImage() -> UIImage? {
    // 座標とかの計算処理など、、
    
    // 重要：向きを考慮したCGImageを作成
    // これにより、UIImageの座標系で計算したクロップ範囲を
    // そのままCGImageに適用できる
    guard let orientedCGImage = createOrientedCGImage(from: originalImage) else {
        return nil
    }
    
    // このCGImageはUIImage.sizeと一致するサイズを持つため、
    // UIImageの座標系で計算したscaledCropRectをそのまま使用できる
    guard let croppedCGImage = orientedCGImage.cropping(to: scaledCropRect) else {
        return nil
    }
    
    return UIImage(cgImage: croppedCGImage)
}
```
## 重要なポイント
- UIGraphicsRendererの使用: 向き情報を自動的に考慮して描画
- 座標計算の一貫性: 常にUIImage.sizeを基準に計算

https://developer.apple.com/documentation/uikit/uiimage/orientation
https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/Introduction/Introduction.html

# ブラー編集をかけた時の問題

## 問題の概要&原因
- CIGaussianBlurは画像の境界を拡散させるため、outputImageのextentが元の画像より大きくなる
- この拡大されたextentのまま表示すると、相対的に画像が小さく見える
- cropped(to: originalExtent)で元のサイズに戻すことで、正しい表示サイズを維持

## 改善方法

### 1. 元の画像範囲（extent）を保存
ブラー処理前に元の画像の範囲を保存しておく：

```swift
let originalExtent = image.extent
```

### 2. ブラー処理後にクロップして範囲を復元
ブラー処理後に元のサイズにクロップすることで、正しい表示サイズを維持：

```swift
guard let blurredImage = filter.outputImage else {
    return image
}

// 元の画像サイズにクロップして範囲を復元
return blurredImage.cropped(to: originalExtent)
```

### 3. 完全な実装例

```swift
/// ガウシアンブラーを適用
static func applyGaussianBlur(to image: CIImage, radius: CGFloat) -> CIImage? {
    // 値が0の場合は変更なし - 処理コストを節約するため、早期リターン
    if radius == 0 {
        return image
    }
    
    // 入力値を0.0〜10.0の範囲に制限（ロゴ制作に適した範囲）
    let clampedRadius = max(0.0, min(10.0, radius))
    
    // 元の画像の範囲を保存
    let originalExtent = image.extent
    
    // ガウシアンブラーフィルターを作成
    guard let filter = CIFilter(name: "CIGaussianBlur") else {
        print("DEBUG: CIGaussianBlurフィルターが使用できません")
        return image
    }
    
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(clampedRadius, forKey: kCIInputRadiusKey)
    
    guard let blurredImage = filter.outputImage else {
        return image
    }
    
    // 元の画像サイズにクロップして範囲を復元
    return blurredImage.cropped(to: originalExtent)
}
```

### 4. 技術的な詳細

#### CIGaussianBlurの動作原理
- **境界拡散**: ブラー処理により画像の境界が周囲に拡散
- **extent変化**: `outputImage.extent`が元の画像より大きくなる
- **表示問題**: 拡大されたextentで描画すると相対的に画像が小さく見える

#### 修正前後の比較
```swift
// 修正前（問題のあるコード）
return filter.outputImage  // extentが拡大されている

// 修正後（正しいコード）
return blurredImage.cropped(to: originalExtent)  // 元のサイズに復元
```

### 5. 他のフィルターでの注意点
同様の問題は他のCore Imageフィルターでも発生する可能性があります：

- **CIBoxBlur**: ボックスブラー
- **CIDiscBlur**: ディスクブラー
- **CIMotionBlur**: モーションブラー
- **CIMorphologyGradient**: モルフォロジーグラデーション

これらのフィルターを使用する際も同様の`cropped(to: originalExtent)`処理が必要です。

### 6. パフォーマンス考慮事項
- **クロップ処理**: 軽量な処理で性能への影響は最小限
- **メモリ効率**: 不要な拡大領域を削除することでメモリ使用量も削減
- **品質維持**: ブラー効果の品質は完全に保持される

この修正により、ガウシアンブラーを適用しても画像が小さくならず、自然なブラー効果を楽しめるようになります。

# UI応答性の改善（高解像度画像対応）

## 問題の概要
高解像度画像（4284×5712、約24.5MP）の編集時に、スライダー操作の反応が遅くなる問題が発生していました。従来の実装では、スライダー操作のたびにフルサイズ画像で処理を行うため、重い処理負荷によりUI応答性が大幅に低下していました。

## 根本原因
- **処理負荷**: 24.5MPの画像処理でメモリ97MB使用、処理時間500ms-2s
- **UIブロッキング**: メインスレッドでの重い処理によるUI凍結
- **無駄な処理**: 連続操作時の重複する高品質処理

## 解決策：2段階処理アーキテクチャ

### 1. システム設計
```
スライダー変更
    ↓ 即座（<16ms）
【Stage 1】低解像度プレビュー（512px）
    ↓ UI即座更新
【Stage 2】フルサイズ処理（バックグラウンド500ms後）
    ↓ 高品質更新
```

### 2. プレビュー画像生成機能

#### プレビュー用低解像度画像の生成
```swift
/// プレビュー用低解像度画像を生成
private func generatePreviewImage() -> UIImage? {
    guard let originalImage = self.originalImage else { return nil }
    
    // 既にプレビューサイズ以下の場合はそのまま使用
    let originalSize = originalImage.size
    let maxDimension = max(originalSize.width, originalSize.height)
    
    if maxDimension <= previewMaxSize {
        return originalImage
    }
    
    // アスペクト比を維持してリサイズ
    let scale = previewMaxSize / maxDimension
    let newSize = CGSize(
        width: originalSize.width * scale,
        height: originalSize.height * scale
    )
    
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    defer { UIGraphicsEndImageContext() }
    
    originalImage.draw(in: CGRect(origin: .zero, size: newSize))
    return UIGraphicsGetImageFromCurrentImageContext()
}
```

#### 即座プレビュー機能
```swift
/// 即座プレビュー用の画像を取得（低解像度、高速処理）
func getInstantPreview() -> UIImage? {
    // プレビュー画像が未生成の場合は生成
    if previewImage == nil {
        previewImage = generatePreviewImage()
    }
    
    guard let preview = previewImage else { return nil }
    
    // プレビューサイズでフィルターを適用
    return applyFilters(to: preview) ?? preview
}
```

### 3. 編集状態管理

#### 編集状態の追跡
```swift
/// 編集中かどうかのフラグ（プレビュー/高品質の切り替え用）
private var isCurrentlyEditing: Bool = false

/// 編集開始をマーク
func startEditing() {
    isCurrentlyEditing = true
}

/// 編集終了をマーク
func stopEditing() {
    isCurrentlyEditing = false
    scheduleHighQualityUpdate()
}
```

### 4. 描画処理の最適化

#### 動的品質切り替え
```swift
// 編集中は即座プレビュー、それ以外は高品質画像を使用
let filteredImage: UIImage
if isCurrentlyEditing {
    filteredImage = getInstantPreview() ?? image    // 512px低解像度
} else {
    filteredImage = applyFilters(to: image) ?? image // フルサイズ
}
```

### 5. 各調整機能への適用

#### 標準的な実装パターン
```swift
/// 彩度調整の更新（例）
func updateSaturation(_ saturation: CGFloat) {
    guard let imageElement = imageElement else { return }
    
    // 現在と同じ値なら何もしない
    if imageElement.saturationAdjustment == saturation { return }
    
    let oldValue = imageElement.saturationAdjustment
    
    // 編集開始をマーク
    imageElement.startEditing()
    
    // 即座に値を更新（UI即座反応のため）
    imageElement.saturationAdjustment = saturation
    
    // EditorViewModelの対応するメソッドを呼び出す（イベントソーシング用）
    editorViewModel?.updateImageSaturation(imageElement, newSaturation: saturation)
    
    // メタデータに編集を記録
    if imageElement.originalImageIdentifier != nil {
        imageElement.recordMetadataEdit(
            fieldKey: "saturationAdjustment",
            oldValue: oldValue,
            newValue: saturation
        )
    }
}
```

### 6. 対象機能一覧

#### 色調整
- ✅ **彩度**: saturationAdjustment
- ✅ **明度**: brightnessAdjustment  
- ✅ **コントラスト**: contrastAdjustment
- ✅ **ハイライト**: highlightsAdjustment
- ✅ **シャドウ**: shadowsAdjustment
- ✅ **色相**: hueAdjustment

#### エフェクト
- ✅ **シャープネス**: sharpnessAdjustment
- ✅ **ガウシアンブラー**: gaussianBlurRadius

#### 視覚効果
- ✅ **フレーム表示**: showFrame
- ✅ **フレーム色**: frameColor
- ✅ **フレーム太さ**: frameWidth
- ✅ **角丸設定**: roundedCorners, cornerRadius
- ✅ **カラーオーバーレイ**: tintColor, tintIntensity

### 7. パフォーマンス改善効果

#### 改善結果の比較
| 項目 | 改善前 | 改善後 | 効果 |
|------|--------|--------|------|
| **UI反応時間** | 500ms-2s | **<16ms** | 3,000-12,500%高速化 |
| **メモリ使用量** | 97MB | **6MB** | 94%削減 |
| **処理負荷** | 24.5MP | **0.26MP** | 99%削減 |
| **スライダー応答性** | 遅延あり | **即座** | リアルタイム編集実現 |

#### 技術的詳細
- **低解像度プレビュー**: 最大512px（4284×5712 → 512×683）
- **処理時間短縮**: 97MB → 1.3MB メモリアクセス
- **デバウンス**: 500ms後に自動的に高品質更新
- **品質保証**: 最終的にはフルサイズで高品質処理

### 8. 実装における注意点

#### メモリ管理
```swift
/// プレビュー用低解像度画像キャッシュ
private var previewImage: UIImage?

/// プレビュー用サイズ（最大512px）
private let previewMaxSize: CGFloat = 512
```

#### タスク管理
```swift
/// 高品質更新用のデバウンスタスク
private var highQualityUpdateTask: Task<Void, Never>?
```

#### キャッシュクリア
```swift
// キャッシュをクリアして再描画を促す
cachedImage = nil
previewImage = nil  // プレビューもリセット
```

### 9. ユーザー体験の向上

この改善により、高解像度画像（4284×5712）でも以下の快適な編集体験が実現されました：

- **即座反応**: 全ての調整操作が16ms以内で視覚反映
- **滑らかな操作**: 連続スライダー操作でも遅延なし
- **自動品質向上**: 編集完了後は自動的に高品質更新
- **メモリ効率**: 編集中は大幅なメモリ使用量削減
- **品質保証**: 最終出力は必ずフルサイズ高品質

この2段階処理アーキテクチャにより、プロフェッショナルレベルの高解像度画像編集における快適なリアルタイム編集が可能になりました。

# Z-Index順タッチ判定システム

## 問題の概要
複数の要素が重なっている状況で、テキストと画像が重なった場合にテキストが選択しにくい問題が発生していました。従来の実装では、配列順（追加順）でタッチ判定を行っていたため、後から追加された要素が前面に描画されていても、タッチ判定では意図しない要素が選択される場合がありました。

## 根本原因
- **描画順序とタッチ判定順序の不一致**: 描画はZ-Index順、タッチ判定は配列順
- **配列順の限界**: 要素の追加順序と視覚的な前後関係が異なる
- **直感的でない操作**: ユーザーが見ている前面の要素を選択できない

## 解決策：Z-Index順タッチ判定

### 1. システム設計
```
要素タイプ別のZ-Index優先度:
- テキスト要素: 300〜（最前面）
- 図形要素: 200〜（中間）
- 画像要素: 100〜（背面）
- 背景要素: 0〜（最背面）
```

### 2. 自動Z-Index設定
```swift
/// 要素の自動Z-Index設定
private func setAutoZIndex(for element: LogoElement) {
    let elementPriority = ElementPriority.defaultPriority(for: element.type)
    let nextZIndex = elementPriority.nextAvailableZIndex(existingElements: project.elements)
    element.zIndex = nextZIndex
    
    print("DEBUG: 要素タイプ: \(element.type), 優先度: \(elementPriority), 設定されたzIndex: \(nextZIndex)")
}
```

### 3. 描画順序の統一
```swift
// Z-Index順でソートしてから描画（小さい値から大きい値へ、奥から手前へ）
let sortedElements = project.elements
    .filter { $0.isVisible }
    .sorted { $0.zIndex < $1.zIndex }

for element in sortedElements {
    element.draw(in: context)
}
```

### 4. タッチ判定の改善
```swift
/// 指定された位置にある要素を検索
private func hitTestElement(at point: CGPoint) -> LogoElement? {
    guard let project = project else { return nil }
    
    let testPoint = snapToGrid ? snapPointToGrid(point) : point
    
    // Z-Index順（大きい値から小さい値へ、前面から奥へ）でヒットテスト
    let sortedElements = project.elements
        .filter { !$0.isLocked && $0.isVisible }
        .sorted { $0.zIndex > $1.zIndex }
    
    return sortedElements.first { $0.hitTest(testPoint) }
}
```

### 5. イベントソーシング対応
```swift
/// 要素のZ-Index変更イベント
struct ElementZIndexChangedEvent: EditorEvent {
    var eventName = "ElementZIndexChanged"
    var timestamp = Date()
    let elementId: UUID
    let oldZIndex: Int
    let newZIndex: Int
    
    func apply(to project: LogoProject) {
        guard let element = project.elements.first(where: { $0.id == elementId }) else { return }
        element.zIndex = newZIndex
    }
    
    func revert(from project: LogoProject) {
        guard let element = project.elements.first(where: { $0.id == elementId }) else { return }
        element.zIndex = oldZIndex
    }
}
```

### 6. 実装における技術的詳細

#### 要素タイプ別優先度システム
```swift
/// 要素の描画優先度を表す列挙型
enum ElementPriority: Int, CaseIterable {
    case background = 0     // 背景要素
    case image = 100        // 画像要素
    case shape = 200        // 図形要素
    case text = 300         // テキスト要素（最前面）
    
    /// 優先度の範囲内で次の利用可能なzIndexを取得
    func nextAvailableZIndex(existingElements: [LogoElement]) -> Int {
        let samePriorityElements = existingElements.filter { element in
            let elementPriority = ElementPriority.priority(for: element.zIndex)
            return elementPriority == self
        }
        
        if samePriorityElements.isEmpty {
            return self.rawValue
        }
        
        let maxZIndex = samePriorityElements.map { $0.zIndex }.max() ?? self.rawValue
        return maxZIndex + 1
    }
}
```

#### 初期化時の自動設定
```swift
// 各要素の初期化時にデフォルトzIndexを設定
init(text: String, fontName: String = "HelveticaNeue", fontSize: CGFloat = 36.0, textColor: UIColor = .white) {
    super.init(name: "Text")
    // ... その他の初期化処理
    
    // デフォルトzIndexを設定
    self.zIndex = ElementPriority.text.rawValue
}
```

### 7. 改善効果

#### 操作性の向上
| 項目 | 改善前 | 改善後 | 効果 |
|------|--------|--------|------|
| **タッチ判定** | 配列順 | **Z-Index順** | 直感的操作 |
| **選択精度** | 不安定 | **確実** | 前面要素を確実に選択 |
| **一貫性** | 描画≠タッチ | **描画=タッチ** | 見た目通りの操作 |
| **保守性** | 複雑 | **シンプル** | 統一されたロジック |

#### 具体的な改善例
- **テキスト＋画像**: テキスト（zIndex=300）が画像（zIndex=100）の前面に確実に選択される
- **図形＋画像**: 図形（zIndex=200）が画像（zIndex=100）の前面に確実に選択される
- **複数テキスト**: 後から追加されたテキスト（zIndex=301）が前面に選択される

### 8. 将来的な拡張性

#### 手動順序変更機能
```swift
// 将来的に実装可能な機能
func bringToFront(_ element: LogoElement) {
    // 最前面に移動
}

func sendToBack(_ element: LogoElement) {
    // 背面に移動
}
```

#### レイヤーパネル
```swift
// レイヤー管理UIとの連携
struct LayerPanelView: View {
    var sortedElements: [LogoElement] {
        editorViewModel.project.elements.sorted { $0.zIndex > $1.zIndex }
    }
}
```

### 9. 実装の核心ポイント

この実装の最も重要な点は、**既存のZ-Index描画システムを活用**して、**1つの関数を修正するだけ**で根本的な問題を解決したことです：

```swift
// 修正前（問題のあるコード）
for element in project.elements.reversed() {
    if element.hitTest(testPoint) {
        return element
        
    }
}

// 修正後（Z-Index順）
let sortedElements = project.elements
    .filter { !$0.isLocked && $0.isVisible }
    .sorted { $0.zIndex > $1.zIndex }

return sortedElements.first { $0.hitTest(testPoint) }
```

この改善により、**ユーザーが見ている通りの順序で要素を選択**できるようになり、直感的で一貫性のある操作体験が実現されました。

# 合成画像保存時の画像消失問題

## 問題の概要
複数の画像を組み合わせて合成画像として保存する際、特定の条件下でオーバーレイ画像（キャラクター等）が保存結果から消失する問題が発生していました。

## 根本原因
**解像度ベースの自動ベース画像選択**により、ユーザーの意図と異なる画像がベースとして選択されることが原因でした：

- **従来ロジック**: 最高解像度の画像を自動的にベース画像として選択
- **問題事例**: キャラクター画像（高解像度）がベースに選ばれ、学校背景（低解像度）がオーバーレイになる
- **結果**: 座標変換時に`relativeX = -2.18`など範囲外座標が計算され、オーバーレイ要素が描画範囲外に配置される

## 解決策：役割ベース画像管理システム

### 1. 画像役割の導入
```swift
/// 画像の役割を定義
enum ImageRole: String, Codable, CaseIterable {
    case base = "base"           // ベース画像（保存時の基準画像）
    case overlay = "overlay"     // オーバーレイ画像（ベース画像の上に重ねる画像）
}
```

### 2. ユーザー制御可能なUI
- **⭐️アイコン**: 画像選択時にツールバーに表示
  - ベース画像：黄色の塗りつぶし星（⭐️）
  - オーバーレイ画像：通常色の輪郭星（☆）
- **直感的操作**: タップで役割を切り替え
- **安全設計**: ベース画像は解除不可（必ず1つのベース画像を維持）

### 3. 保存アルゴリズムの改善
```swift
// 1. まずベース役割の画像を探す
baseImageElement = imageElements.first { $0.imageRole == .base }

// 2. ベース役割がない場合は、最高解像度の画像を選択（既存ロジック）
if baseImageElement == nil {
    // フォールバック処理
}
```

### 4. 視覚的レイヤー順序の自動調整
- **ベース画像**: `ElementPriority.image.rawValue - 10` (背面配置)
- **オーバーレイ画像**: `ElementPriority.image.rawValue + 10` (前面配置)
- **自動ソート**: 役割変更時に`project.elements`をzIndex順で並び替え

## 改善効果

| 項目 | 改善前 | 改善後 | 効果 |
|------|--------|--------|------|
| **画像選択** | 解像度依存 | **ユーザー指定** | 意図通りの保存 |
| **座標計算** | 範囲外エラー | **0.0-1.0範囲** | 正確な位置計算 |
| **操作性** | 自動選択のみ | **⭐️で直感操作** | ユーザー制御 |
| **安全性** | 不安定 | **必ずベース画像存在** | 保存失敗防止 |

この実装により、ユーザーが明示的に指定したベース画像を基準とした正確な合成画像保存が可能になり、オーバーレイ要素の消失問題が解決。
