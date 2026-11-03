// フィルターパラメータの合成規則と、描画・サムネイルの両経路が同じ合成結果を受け取ることを検証する。

import UIKit
import XCTest
@testable import GLogo

final class ImageFilterParamsComposerTests: XCTestCase {
    func test_compose_withoutRecipe_passesManualValues() {
        let values = makeDistinctValues()
        let params = ImageFilterParamsComposer.compose(values, recipe: nil)
        assertParams(params, equal: values)
    }

    func test_compose_appliesRecipeRules() {
        let values = makeDistinctValues()
        let recipe = FilterRecipe(saturation: 1.5, brightness: 0.2, contrast: 2.0, highlights: 0.3,
                                  shadows: 0.4, hue: 5, sharpness: 0.5, gaussianBlur: 2,
                                  tintColorHex: "#FF0000", tintIntensity: 0.6)
        let params = ImageFilterParamsComposer.compose(values, recipe: recipe)

        // 乗算系
        XCTAssertEqual(params.saturation, 1.5 * values.saturation, accuracy: 0.0001)
        XCTAssertEqual(params.contrast, 2.0 * values.contrast, accuracy: 0.0001)
        // 加算系
        XCTAssertEqual(params.brightness, 0.2 + values.brightness, accuracy: 0.0001)
        XCTAssertEqual(params.highlights, 0.3 + values.highlights, accuracy: 0.0001)
        XCTAssertEqual(params.shadows, 0.4 + values.shadows, accuracy: 0.0001)
        XCTAssertEqual(params.hue, 5 + values.hue, accuracy: 0.0001)
        XCTAssertEqual(params.sharpness, 0.5 + values.sharpness, accuracy: 0.0001)
        XCTAssertEqual(params.gaussianBlurRadius, 2 + values.gaussianBlurRadius, accuracy: 0.0001)
        // レシピがティントを持つ場合は置き換え
        XCTAssertTrue(params.tintColor?.isEqual(UIColor(hex: "#FF0000")) == true)
        XCTAssertEqual(params.tintIntensity, 0.6, accuracy: 0.0001)
        // レシピに項目がない値は手動値のまま
        XCTAssertEqual(params.blacks, values.blacks)
        XCTAssertEqual(params.whites, values.whites)
        XCTAssertEqual(params.warmth, values.warmth)
        XCTAssertEqual(params.vibrance, values.vibrance)
        XCTAssertEqual(params.vignetteIntensity, values.vignette)
        XCTAssertEqual(params.bloomIntensity, values.bloom)
        XCTAssertEqual(params.grainIntensity, values.grain)
        XCTAssertEqual(params.fadeIntensity, values.fade)
        XCTAssertEqual(params.chromaticAberrationIntensity, values.chromaticAberration)
        XCTAssertEqual(params.backgroundBlurRadius, values.backgroundBlurRadius)
        XCTAssertEqual(params.backgroundBlurMaskData, values.backgroundBlurMaskData)
        XCTAssertEqual(params.toneCurveData, values.toneCurveData)
    }

    func test_compose_recipeWithoutTint_keepsManualTint() {
        let values = makeDistinctValues()
        let params = ImageFilterParamsComposer.compose(values, recipe: FilterRecipe(saturation: 1.2))
        XCTAssertTrue(params.tintColor?.isEqual(values.tintColor) == true)
        XCTAssertEqual(params.tintIntensity, values.tintIntensity)
    }

    /// 要素に設定した全調整値が、取り違えなく描画サービスへ届くことを確認する。
    func test_elementRendering_passesAllAdjustments() throws {
        let spy = FilterParamsSpy()
        let element = try makeElement(service: spy)
        let expected = makeDistinctValues()
        apply(expected, to: element)

        XCTAssertNotNil(element.getFilteredImageForce())
        let params = try XCTUnwrap(spy.lastParams)
        assertParams(params, equal: expected)
    }

    /// 回帰: サムネイルにだけ効果系（ビネット等）が入らず、適用後の見た目と一致しなかった。
    @MainActor
    func test_thumbnail_matchesAppliedComposition() async throws {
        let spy = FilterParamsSpy()
        let element = try makeElement(service: spy)
        apply(makeDistinctValues(), to: element)
        let project = LogoProject()
        project.addElement(element)
        let editor = EditorViewModel(project: project)
        let panels = ElementViewModel(editorViewModel: editor)
        editor.selectElement(element)
        let preset = FilterCatalog.noir

        _ = await panels.filters.generateFilterPreview(for: preset, targetSize: CGSize(width: 20, height: 20))

        let thumbnail = try XCTUnwrap(spy.lastParams)
        let applied = ImageFilterParamsComposer.compose(element.adjustmentValues, recipe: preset.recipe)
        XCTAssertEqual(thumbnail.vignetteIntensity, 0.13)
        XCTAssertEqual(thumbnail.bloomIntensity, 0.14)
        XCTAssertEqual(thumbnail.grainIntensity, 0.15)
        XCTAssertEqual(thumbnail.fadeIntensity, 0.16)
        XCTAssertEqual(thumbnail.chromaticAberrationIntensity, 0.17)
        assertParams(thumbnail, equal: applied)
        withExtendedLifetime(panels) {}
    }

    // MARK: - Test Support

    /// 項目の取り違えを検出できるよう、全項目に異なる値を入れる。
    private func makeDistinctValues() -> ImageAdjustmentValues {
        ImageAdjustmentValues(
            saturation: 0.91, brightness: 0.02, contrast: 1.03, highlights: 0.04, shadows: 0.05,
            blacks: 0.06, whites: 0.07, warmth: 0.08, vibrance: 0.09, hue: 10, sharpness: 0.11,
            gaussianBlurRadius: 1.2, vignette: 0.13, bloom: 0.14, grain: 0.15, fade: 0.16,
            chromaticAberration: 0.17, toneCurveData: ToneCurveData(), tintColor: .green,
            tintIntensity: 0.18, backgroundBlurRadius: 1.9, backgroundBlurMaskData: Data([1, 2, 3])
        )
    }

    private func apply(_ values: ImageAdjustmentValues, to element: ImageElement) {
        element.saturationAdjustment = values.saturation
        element.brightnessAdjustment = values.brightness
        element.contrastAdjustment = values.contrast
        element.highlightsAdjustment = values.highlights
        element.shadowsAdjustment = values.shadows
        element.blacksAdjustment = values.blacks
        element.whitesAdjustment = values.whites
        element.warmthAdjustment = values.warmth
        element.vibranceAdjustment = values.vibrance
        element.hueAdjustment = values.hue
        element.sharpnessAdjustment = values.sharpness
        element.gaussianBlurRadius = values.gaussianBlurRadius
        element.vignetteAdjustment = values.vignette
        element.bloomAdjustment = values.bloom
        element.grainAdjustment = values.grain
        element.fadeAdjustment = values.fade
        element.chromaticAberrationAdjustment = values.chromaticAberration
        element.toneCurveData = values.toneCurveData
        element.tintColor = values.tintColor
        element.tintIntensity = values.tintIntensity
        element.backgroundBlurRadius = values.backgroundBlurRadius
        element.backgroundBlurMaskData = values.backgroundBlurMaskData
    }

    /// レシピがない場合の期待値。合成処理を使わず、手動値がそのまま各項目へ入ることを直接比べる。
    private func assertParams(_ params: ImageFilterParams, equal values: ImageAdjustmentValues,
                              file: StaticString = #filePath, line: UInt = #line) {
        let expected = ImageFilterParams(
            toneCurveData: values.toneCurveData, saturation: values.saturation, brightness: values.brightness,
            contrast: values.contrast, highlights: values.highlights, shadows: values.shadows,
            blacks: values.blacks, whites: values.whites, warmth: values.warmth, vibrance: values.vibrance,
            hue: values.hue, sharpness: values.sharpness, gaussianBlurRadius: values.gaussianBlurRadius,
            vignetteIntensity: values.vignette, bloomIntensity: values.bloom, grainIntensity: values.grain,
            fadeIntensity: values.fade, chromaticAberrationIntensity: values.chromaticAberration,
            tintColor: values.tintColor, tintIntensity: values.tintIntensity,
            backgroundBlurRadius: values.backgroundBlurRadius, backgroundBlurMaskData: values.backgroundBlurMaskData
        )
        assertParams(params, equal: expected, file: file, line: line)
    }

    private func assertParams(_ actual: ImageFilterParams, equal expected: ImageFilterParams,
                              file: StaticString = #filePath, line: UInt = #line) {
        let pairs: [(String, CGFloat, CGFloat)] = [
            ("saturation", actual.saturation, expected.saturation),
            ("brightness", actual.brightness, expected.brightness),
            ("contrast", actual.contrast, expected.contrast),
            ("highlights", actual.highlights, expected.highlights),
            ("shadows", actual.shadows, expected.shadows),
            ("blacks", actual.blacks, expected.blacks),
            ("whites", actual.whites, expected.whites),
            ("warmth", actual.warmth, expected.warmth),
            ("vibrance", actual.vibrance, expected.vibrance),
            ("hue", actual.hue, expected.hue),
            ("sharpness", actual.sharpness, expected.sharpness),
            ("gaussianBlurRadius", actual.gaussianBlurRadius, expected.gaussianBlurRadius),
            ("vignette", actual.vignetteIntensity, expected.vignetteIntensity),
            ("bloom", actual.bloomIntensity, expected.bloomIntensity),
            ("grain", actual.grainIntensity, expected.grainIntensity),
            ("fade", actual.fadeIntensity, expected.fadeIntensity),
            ("chromaticAberration", actual.chromaticAberrationIntensity, expected.chromaticAberrationIntensity),
            ("tintIntensity", actual.tintIntensity, expected.tintIntensity),
            ("backgroundBlurRadius", actual.backgroundBlurRadius, expected.backgroundBlurRadius)
        ]
        for (name, value, expectedValue) in pairs {
            XCTAssertEqual(value, expectedValue, accuracy: 0.0001, name, file: file, line: line)
        }
        XCTAssertEqual(actual.toneCurveData, expected.toneCurveData, file: file, line: line)
        XCTAssertEqual(actual.backgroundBlurMaskData, expected.backgroundBlurMaskData, file: file, line: line)
        XCTAssertEqual(actual.tintColor == nil, expected.tintColor == nil, "tintColor", file: file, line: line)
        if let color = actual.tintColor, let expectedColor = expected.tintColor {
            XCTAssertTrue(color.isEqual(expectedColor), "tintColor", file: file, line: line)
        }
    }

    private func makeElement(service: any ImagePreviewing) throws -> ImageElement {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
        let data = try XCTUnwrap(image.pngData())
        return ImageElementFactory(previewService: service).makeElement(imageData: data)
    }
}

/// 描画サービスへ渡されたパラメータ全体を記録する。
private final class FilterParamsSpy: ImagePreviewing, @unchecked Sendable {
    private let lock = NSLock()
    private var params: ImageFilterParams?
    private let output = UIImage()

    var lastParams: ImageFilterParams? { lock.withLock { params } }

    func generatePreviewImage(editingImage: UIImage?, originalImage: UIImage?, mode: ImageRenderMode) -> UIImage? {
        editingImage ?? originalImage
    }

    func instantPreview(baseImage: UIImage?, params: ImageFilterParams,
                        quality: ToneCurveFilter.Quality, mode: ImageRenderMode) -> UIImage? {
        record(params)
        return output
    }

    func applyFilters(to image: UIImage, params: ImageFilterParams,
                      quality: ToneCurveFilter.Quality, mode: ImageRenderMode) -> UIImage? {
        record(params)
        return output
    }

    func applyFiltersAsync(to image: UIImage, params: ImageFilterParams,
                           quality: ToneCurveFilter.Quality, mode: ImageRenderMode) async -> UIImage? {
        record(params)
        return output
    }

    func resetCache() {}

    private func record(_ params: ImageFilterParams) {
        lock.withLock { self.params = params }
    }
}
