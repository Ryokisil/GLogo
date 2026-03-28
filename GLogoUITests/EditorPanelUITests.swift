//
//  EditorPanelUITests.swift
//  GLogoUITests
//
//  概要:
//  エディタ下部パネル（Adjust / Effects / Filters / Frame / AI Tools / Text）の
//  開閉・control 選択・slider 操作・reset・プリセット選択を守る UI テスト。
//

import XCTest

final class EditorPanelUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// fixture なしで起動する
    @MainActor
    private func launchApp() {
        app = XCUIApplication()
        app.launchArguments += ["-hasSeenEditorIntro", "YES"]
        app.launch()
    }

    /// fixture 付きで起動する
    @MainActor
    private func launchApp(fixture: String) {
        app = XCUIApplication()
        app.launchArguments += ["-hasSeenEditorIntro", "YES"]
        app.launchArguments += ["-uiTestFixture", fixture]
        app.launch()
    }

    // MARK: - Frame パネルテスト

    /// Frame パネルを開くとスタイルプリセットが表示される
    @MainActor
    func testEditor_FramePanel_ShowsPresets() throws {
        launchApp(fixture: "selectedImage")

        let frameToolButton = app.buttons["editor.bottomTool.frame"]
        XCTAssertTrue(frameToolButton.waitForExistence(timeout: 5), "フレームツールボタンが表示されるべき")
        frameToolButton.tap()

        // パネルが開いたことを閉じるボタンで確認
        let closeButton = app.buttons["editor.framePanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "フレームパネルが表示されるべき")
    }

    /// Frame パネルでスタイルを選択すると remove ボタンが有効化される
    @MainActor
    func testEditor_FramePanel_SelectsPreset() throws {
        launchApp(fixture: "selectedImage")

        let frameButton = app.buttons["editor.bottomTool.frame"]
        XCTAssertTrue(frameButton.waitForExistence(timeout: 5), "Frameボタンが表示されるべき")
        frameButton.tap()

        let closeButton = app.buttons["editor.framePanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Frameパネルが表示されるべき")

        // 初期状態では remove は無効
        let removeButton = app.buttons["editor.framePanel.removeButton"]
        XCTAssertTrue(removeButton.exists, "Removeボタンが表示されるべき")
        XCTAssertFalse(removeButton.isEnabled, "初期状態ではRemoveボタンが無効であるべき")

        // simple スタイルをタップ
        let simpleStyle = app.buttons["editor.frameStyle.simple"]
        XCTAssertTrue(simpleStyle.waitForExistence(timeout: 3), "Simpleスタイルカードが表示されるべき")
        simpleStyle.tap()

        // remove が有効になる
        let removeEnabled = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: removeEnabled, object: removeButton)
        let result = XCTWaiter().wait(for: [expectation], timeout: 3)
        XCTAssertEqual(result, .completed, "スタイル選択後にRemoveボタンが有効になるべき")
    }

    // MARK: - AI Tools パネルテスト

    /// AI Tools パネルの Enhance タブが画像選択時に表示される
    @MainActor
    func testEditor_AIToolsPanel_ShowsEnhanceForSelectedImage() throws {
        launchApp(fixture: "selectedImage")

        let aiToolButton = app.buttons["editor.bottomTool.magicStudio"]
        XCTAssertTrue(aiToolButton.waitForExistence(timeout: 5))
        aiToolButton.tap()

        // パネルが開いたことを確認
        let closeButton = app.buttons["editor.aiToolsPanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "AI Toolsパネルが表示されるべき")

        // Enhance タブに切り替え
        let enhanceTab = app.buttons["editor.aiToolsTab.upscale"]
        XCTAssertTrue(enhanceTab.exists, "Enhanceタブが表示されるべき")
        enhanceTab.tap()

        // Enhance ボタンが存在する
        let enhanceButton = app.buttons["editor.aiTools.enhanceButton"]
        XCTAssertTrue(enhanceButton.waitForExistence(timeout: 2), "Enhanceボタンが表示されるべき")
    }

    /// 高画質化済み画像では Enhance ボタンが無効化される
    @MainActor
    func testEditor_EnhancedImage_DisablesEnhanceButton() throws {
        launchApp(fixture: "enhancedImage")

        let aiToolButton = app.buttons["editor.bottomTool.magicStudio"]
        XCTAssertTrue(aiToolButton.waitForExistence(timeout: 5))
        aiToolButton.tap()

        let closeButton = app.buttons["editor.aiToolsPanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))

        // Enhance タブに切り替え
        let enhanceTab = app.buttons["editor.aiToolsTab.upscale"]
        enhanceTab.tap()

        // Enhance ボタンが無効化されている
        let enhanceButton = app.buttons["editor.aiTools.enhanceButton"]
        XCTAssertTrue(enhanceButton.waitForExistence(timeout: 2), "Enhanceボタンが表示されるべき")
        XCTAssertFalse(enhanceButton.isEnabled, "高画質化済みではEnhanceボタンが無効化されるべき")
    }

    // MARK: - Text パネルテスト

    /// Text ツールタップ後に主要タブが表示される
    @MainActor
    func testEditor_TextPropertyPanel_ShowsPrimaryTabs() throws {
        launchApp()

        let textToolButton = app.buttons["editor.bottomTool.select"]
        XCTAssertTrue(textToolButton.waitForExistence(timeout: 5))
        textToolButton.tap()

        let closeButton = app.buttons["editor.textPropertyPanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "テキストパネルが表示されるべき")

        // 主要タブの存在確認
        let contentTab = app.buttons["editor.textTab.content"]
        XCTAssertTrue(contentTab.exists, "Contentタブが表示されるべき")

        let fontTab = app.buttons["editor.textTab.font"]
        XCTAssertTrue(fontTab.exists, "Fontタブが表示されるべき")

        let colorTab = app.buttons["editor.textTab.color"]
        XCTAssertTrue(colorTab.exists, "Colorタブが表示されるべき")
    }

    // MARK: - Adjust パネルテスト

    /// Adjust パネルが画像選択時に開く
    @MainActor
    func testEditor_AdjustPanel_OpensForSelectedImage() throws {
        launchApp(fixture: "selectedImage")

        let adjustButton = app.buttons["editor.bottomTool.adjust"]
        XCTAssertTrue(adjustButton.waitForExistence(timeout: 5), "Adjustボタンが表示されるべき")
        adjustButton.tap()

        let closeButton = app.buttons["editor.adjustPanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Adjustパネルが表示されるべき")
    }

    /// Adjust パネルで brightness control を選択できる
    /// （初期選択 contrast=1.00 → brightness=0.00 への切り替えで選択成功を検証）
    @MainActor
    func testEditor_AdjustPanel_SelectsBrightnessControl() throws {
        launchApp(fixture: "selectedImage")

        let adjustButton = app.buttons["editor.bottomTool.adjust"]
        XCTAssertTrue(adjustButton.waitForExistence(timeout: 5))
        adjustButton.tap()

        let closeButton = app.buttons["editor.adjustPanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))

        // 初期選択は contrast（デフォルト値 1.00）
        let valueLabel = app.staticTexts["editor.adjustPanel.valueLabel"]
        XCTAssertTrue(valueLabel.waitForExistence(timeout: 2), "値ラベルが表示されるべき")
        XCTAssertEqual(valueLabel.label, "1.00", "初期選択contrastのデフォルト値は1.00であるべき")

        // brightness control をタップ（デフォルト値 0.00）
        let brightnessButton = app.buttons["editor.adjustControl.brightness"]
        XCTAssertTrue(brightnessButton.exists, "Brightnessコントロールが表示されるべき")
        brightnessButton.tap()

        // 値ラベルが 0.00 に変わることで選択切り替えを確認
        let switched = NSPredicate(format: "label == '0.00'")
        let expectation = XCTNSPredicateExpectation(predicate: switched, object: valueLabel)
        let result = XCTWaiter().wait(for: [expectation], timeout: 3)
        XCTAssertEqual(result, .completed, "Brightness選択後にデフォルト値0.00が表示されるべき")
    }

    /// slider を動かすと値ラベルが更新される
    @MainActor
    func testEditor_AdjustPanel_SliderValueChangesLive() throws {
        launchApp(fixture: "selectedImage")

        let adjustButton = app.buttons["editor.bottomTool.adjust"]
        XCTAssertTrue(adjustButton.waitForExistence(timeout: 5))
        adjustButton.tap()

        let closeButton = app.buttons["editor.adjustPanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))

        // brightness を選択（デフォルト値 0.00、変化がわかりやすい）
        let brightnessButton = app.buttons["editor.adjustControl.brightness"]
        XCTAssertTrue(brightnessButton.exists, "Brightnessコントロールが表示されるべき")
        brightnessButton.tap()

        let valueLabel = app.staticTexts["editor.adjustPanel.valueLabel"]
        XCTAssertTrue(valueLabel.waitForExistence(timeout: 2))
        let initialValue = valueLabel.label

        // slider を右方向へ操作
        let slider = app.sliders["editor.adjustPanel.slider"]
        XCTAssertTrue(slider.exists, "スライダーが表示されるべき")
        slider.adjust(toNormalizedSliderPosition: 0.8)

        // 値ラベルが初期値から変化していることを確認
        let updatedValue = valueLabel.label
        XCTAssertNotEqual(updatedValue, initialValue, "スライダー操作後に値が変化するべき")
    }

    /// reset ボタンで初期状態に戻る
    @MainActor
    func testEditor_AdjustPanel_ResetRestoresDefaultState() throws {
        launchApp(fixture: "selectedImage")

        let adjustButton = app.buttons["editor.bottomTool.adjust"]
        XCTAssertTrue(adjustButton.waitForExistence(timeout: 5))
        adjustButton.tap()

        let closeButton = app.buttons["editor.adjustPanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))

        // brightness を選択
        let brightnessButton = app.buttons["editor.adjustControl.brightness"]
        brightnessButton.tap()

        let resetButton = app.buttons["editor.adjustPanel.resetButton"]
        XCTAssertTrue(resetButton.exists, "リセットボタンが表示されるべき")
        // 初期状態では reset は無効
        XCTAssertFalse(resetButton.isEnabled, "初期状態ではリセットボタンが無効であるべき")

        // slider を操作して値を変更
        let slider = app.sliders["editor.adjustPanel.slider"]
        slider.adjust(toNormalizedSliderPosition: 0.8)

        // reset が有効になる
        XCTAssertTrue(resetButton.isEnabled, "値変更後はリセットボタンが有効であるべき")

        // reset をタップ
        resetButton.tap()

        // reset が再び無効に戻る
        let resetDisabled = NSPredicate(format: "isEnabled == false")
        let expectation = XCTNSPredicateExpectation(predicate: resetDisabled, object: resetButton)
        let result = XCTWaiter().wait(for: [expectation], timeout: 3)
        XCTAssertEqual(result, .completed, "リセット後にリセットボタンが無効に戻るべき")

        // 値ラベルがデフォルト値に戻る
        let valueLabel = app.staticTexts["editor.adjustPanel.valueLabel"]
        XCTAssertEqual(valueLabel.label, "0.00", "リセット後にデフォルト値(0.00)に戻るべき")
    }

    /// Adjust パネルでカテゴリをまたいで control を切り替えられる
    /// （Light/contrast=1.00 → Color/temperature=0 への cross-category 切替を検証）
    @MainActor
    func testEditor_AdjustPanel_CategorySwitchesControls() throws {
        launchApp(fixture: "selectedImage")

        let adjustButton = app.buttons["editor.bottomTool.adjust"]
        XCTAssertTrue(adjustButton.waitForExistence(timeout: 5))
        adjustButton.tap()

        let closeButton = app.buttons["editor.adjustPanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3))

        // 初期選択は contrast（Light カテゴリ、デフォルト値 1.00）
        let valueLabel = app.staticTexts["editor.adjustPanel.valueLabel"]
        XCTAssertTrue(valueLabel.waitForExistence(timeout: 2))
        XCTAssertEqual(valueLabel.label, "1.00", "初期選択contrastの値は1.00であるべき")

        // temperature（Color カテゴリ、デフォルト値 0）をタップ
        let temperatureButton = app.buttons["editor.adjustControl.temperature"]
        XCTAssertTrue(temperatureButton.exists, "Temperatureコントロールが表示されるべき")
        temperatureButton.tap()

        // 値ラベルが 0 に変わることで cross-category 切替を確認
        let switched = NSPredicate(format: "label == '0'")
        let expectation = XCTNSPredicateExpectation(predicate: switched, object: valueLabel)
        let result = XCTWaiter().wait(for: [expectation], timeout: 3)
        XCTAssertEqual(result, .completed, "Temperature選択後にデフォルト値0が表示されるべき")
    }

    // MARK: - Effects パネルテスト

    /// Effects パネルを開いて slider 操作で値が変化する
    @MainActor
    func testEditor_EffectsPanel_OpensAndSliderChangesValue() throws {
        launchApp(fixture: "selectedImage")

        let effectsButton = app.buttons["editor.bottomTool.effects"]
        XCTAssertTrue(effectsButton.waitForExistence(timeout: 5), "Effectsボタンが表示されるべき")
        effectsButton.tap()

        let closeButton = app.buttons["editor.effectsPanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Effectsパネルが表示されるべき")

        // 初期選択は vignette（デフォルト値 0.00）
        let valueLabel = app.staticTexts["editor.effectsPanel.valueLabel"]
        XCTAssertTrue(valueLabel.waitForExistence(timeout: 2), "値ラベルが表示されるべき")
        let initialValue = valueLabel.label

        // slider を操作
        let slider = app.sliders["editor.effectsPanel.slider"]
        XCTAssertTrue(slider.exists, "スライダーが表示されるべき")
        slider.adjust(toNormalizedSliderPosition: 0.7)

        // 値が変化していることを確認
        XCTAssertNotEqual(valueLabel.label, initialValue, "スライダー操作後に値が変化するべき")
    }

    // MARK: - Filters パネルテスト

    /// Filters パネルを開いてプリセット選択で reset が有効化される
    @MainActor
    func testEditor_FiltersPanel_OpensAndSelectsPreset() throws {
        launchApp(fixture: "selectedImage")

        let filtersButton = app.buttons["editor.bottomTool.filters"]
        XCTAssertTrue(filtersButton.waitForExistence(timeout: 5), "Filtersボタンが表示されるべき")
        filtersButton.tap()

        let closeButton = app.buttons["editor.filtersPanel.closeButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Filtersパネルが表示されるべき")

        // 初期状態では reset は無効
        let resetButton = app.buttons["editor.filtersPanel.resetButton"]
        XCTAssertTrue(resetButton.exists, "リセットボタンが表示されるべき")
        XCTAssertFalse(resetButton.isEnabled, "初期状態ではリセットボタンが無効であるべき")

        // original 以外のプリセットをタップ（original は初期状態と同じため reset が有効にならない）
        let presetCards = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'editor.filterPreset.' AND identifier != 'editor.filterPreset.original'")
        )
        let presetCard = presetCards.firstMatch
        XCTAssertTrue(presetCard.waitForExistence(timeout: 5), "プリセットカードが表示されるべき")
        presetCard.tap()

        // reset が有効になる
        let resetEnabled = NSPredicate(format: "isEnabled == true")
        let expectation = XCTNSPredicateExpectation(predicate: resetEnabled, object: resetButton)
        let result = XCTWaiter().wait(for: [expectation], timeout: 3)
        XCTAssertEqual(result, .completed, "プリセット選択後にリセットボタンが有効になるべき")
    }
}
