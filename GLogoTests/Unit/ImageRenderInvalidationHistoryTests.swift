// 履歴が、イベントの示す描画キャッシュの失効を、適用・Undo・Redo の直後にエディタの管理役へ求めることを確かめる。
// 画像の見た目を変える27種は、空の既定（何も失効させない）に落ちていないことを、種類ごとに確かめる。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageRenderInvalidationHistoryTests: XCTestCase {
    /// 27種すべてで、適用・Undo・Redo のたびに、対象の要素の表示画像だけを失効させる。
    func test_appearanceEvents_invalidateRenderedOnEveryStep() throws {
        let fixture = Fixture()
        let events = appearanceEvents(for: fixture.image.id)
        XCTAssertEqual(events.count, 27)
        XCTAssertEqual(Set(events.map { String(describing: type(of: $0)) }).count, 27, "種類が重複していない")
        let marker = snapshotImage(.black)
        let expected = [RenderSessionSpy.Control(.invalidate(.rendered), fixture.image)]

        for event in events {
            let name = String(describing: type(of: event))
            for (step, operate) in [
                ("適用", { fixture.history.recordAndApply(event) }),
                ("Undo", { XCTAssertTrue(fixture.history.undo()) }),
                ("Redo", { XCTAssertTrue(fixture.history.redo()) })
            ] as [(String, () -> Void)] {
                fixture.image.cachedImage = marker
                fixture.renderSessions.removeAllRequests()
                operate()
                XCTAssertEqual(fixture.renderSessions.controls, expected, "\(name) の\(step)")
                XCTAssertNil(fixture.image.cachedImage, "\(name) の\(step)で表示画像が消える")
            }
        }
    }

    /// 失効は、適用で値が変わったあと、履歴の呼び出しの中で同期に行う（タスクへ遅らせない）。
    func test_invalidation_runsSynchronouslyAfterApply() {
        let fixture = Fixture()
        var observedValue: CGFloat?
        fixture.renderSessions.onControl = { _, element in
            observedValue = element.saturationAdjustment
        }

        fixture.history.recordAndApply(
            ImageSaturationChangedEvent(elementId: fixture.image.id, oldSaturation: 1.0, newSaturation: 1.7)
        )
        XCTAssertEqual(observedValue, 1.7, "適用のあとで、呼び出しが返る前に失効させる")

        observedValue = nil
        fixture.history.undo()
        XCTAssertEqual(observedValue, 1.0, "巻き戻しのあとで、呼び出しが返る前に失効させる")
    }

    /// 示された ID の画像要素がプロジェクトにないときは、何も求めない（イベント側の扱いと同じ）。
    func test_missingElement_isSkipped() {
        let fixture = Fixture()
        fixture.history.recordAndApply(
            ImageSaturationChangedEvent(elementId: UUID(), oldSaturation: 1.0, newSaturation: 1.7)
        )
        XCTAssertEqual(fixture.renderSessions.controls, [])
    }

    /// 画像の見た目を変えないイベントは、何も失効させない（空の既定）。
    func test_nonImageEvents_doNotInvalidate() {
        let fixture = Fixture()
        let text = TextElement(text: "A")
        fixture.history.recordAndApply(ElementAddedEvent(element: text))
        fixture.history.recordAndApply(ProjectNameChangedEvent(oldName: "", newName: "B"))
        fixture.history.undo()
        fixture.history.redo()
        XCTAssertEqual(fixture.renderSessions.controls, [])
    }

    // MARK: - Helpers

    /// 画像要素1つのプロジェクトと、問い合わせを記録する管理役を使う履歴。
    @MainActor
    private struct Fixture {
        let project = LogoProject()
        let image: ImageElement
        let renderSessions = RenderSessionSpy()
        let history: EditorHistory

        init() {
            image = ImageElementFactory().makeElement(imageData: snapshotImage(.red).pngData()!)
            project.addElement(image)
            history = EditorHistory(project: project, renderSessions: renderSessions)
        }
    }

    /// 画像の見た目を変える27種（調整21・フレーム6）。値は適用と巻き戻しで変わるように選ぶ。
    private func appearanceEvents(for id: UUID) -> [EditorEvent] {
        [
            ImageSaturationChangedEvent(elementId: id, oldSaturation: 1.0, newSaturation: 1.5),
            ImageBrightnessChangedEvent(elementId: id, oldBrightness: 0, newBrightness: 0.2),
            ImageContrastChangedEvent(elementId: id, oldContrast: 1.0, newContrast: 1.2),
            ImageHighlightsChangedEvent(elementId: id, oldHighlights: 0, newHighlights: 0.3),
            ImageShadowsChangedEvent(elementId: id, oldShadows: 0, newShadows: 0.3),
            ImageBlacksChangedEvent(elementId: id, oldBlacks: 0, newBlacks: 0.3),
            ImageWhitesChangedEvent(elementId: id, oldWhites: 0, newWhites: 0.3),
            ImageWarmthChangedEvent(elementId: id, oldWarmth: 0, newWarmth: 0.3),
            ImageVibranceChangedEvent(elementId: id, oldVibrance: 0, newVibrance: 0.3),
            ImageHueChangedEvent(elementId: id, oldHue: 0, newHue: 30),
            ImageSharpnessChangedEvent(elementId: id, oldSharpness: 0, newSharpness: 0.5),
            ImageGaussianBlurChangedEvent(elementId: id, oldRadius: 0, newRadius: 2),
            ImageVignetteChangedEvent(elementId: id, oldIntensity: 0, newIntensity: 0.5),
            ImageBloomChangedEvent(elementId: id, oldIntensity: 0, newIntensity: 0.5),
            ImageGrainChangedEvent(elementId: id, oldIntensity: 0, newIntensity: 0.5),
            ImageFadeChangedEvent(elementId: id, oldIntensity: 0, newIntensity: 0.5),
            ImageChromaticAberrationChangedEvent(elementId: id, oldIntensity: 0, newIntensity: 0.5),
            ImageTintColorChangedEvent(elementId: id, oldColor: nil, newColor: .blue, oldIntensity: 0, newIntensity: 0.5),
            ImageBackgroundBlurMaskChangedEvent(elementId: id, oldMaskData: nil, newMaskData: Data([1, 2, 3])),
            ImageBackgroundBlurRadiusChangedEvent(elementId: id, oldRadius: 0, newRadius: 6),
            FilterPresetChangedEvent(
                elementId: id, oldRecipe: nil, newRecipe: FilterCatalog.vintageWarm.recipe,
                oldPresetId: nil, newPresetId: FilterCatalog.vintageWarm.id
            ),
            ImageShowFrameChangedEvent(elementId: id, oldValue: false, newValue: true),
            ImageFrameColorChangedEvent(elementId: id, oldColor: .black, newColor: .white),
            ImageFrameWidthChangedEvent(elementId: id, oldWidth: 1, newWidth: 3),
            ImageFrameStyleChangedEvent(elementId: id, oldStyle: .simple, newStyle: .film),
            ImageFrameAppearanceChangedEvent(
                elementId: id, oldShowFrame: false, newShowFrame: true, oldFrameStyle: .simple, newFrameStyle: .badge,
                oldFrameColor: .black, newFrameColor: .cyan
            ),
            ImageRoundedCornersChangedEvent(elementId: id, wasRounded: false, isRounded: true, oldRadius: 0, newRadius: 12)
        ]
    }
}
