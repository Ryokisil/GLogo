// ImageElementRenderer が描く中身（配置・透明度・回転・角丸・フレーム11種とその色・描かない条件・描画状態の戻し）と、
// キャンバスの描き方・削除エフェクト・保存の合成の3つの入口が描く画素を確かめる。
// 描画は、UIKit の現在の描画先が渡した context と一致する前提で呼ぶ（このテストも UIGraphicsImageRenderer の描画ブロックの中で呼ぶ）。
// 期待する色は本番の描画処理から作らず、描画の式からテストの中で計算した値にし、輪郭のアンチエイリアスにかからない点で見る。
// 入口は、直接の描画との一致に加えて、画像本体と白系3種の塗りを単独でも確かめる（同じ欠落が両方に出ても気づけるように）。

import UIKit
import XCTest
@testable import GLogo

@MainActor
final class ImageElementRendererTests: XCTestCase {
    // MARK: - 描画の中身

    func test_draw_placesImage() throws {
        let element = makeElement(frame: CGRect(x: 10, y: 20, width: 30, height: 20))
        let pixels = try Pixels(render(CGSize(width: 60, height: 60)) {
            ImageElementRenderer.draw(element, in: $0, image: solidImage(.red, CGSize(width: 30, height: 20)))
        })

        pixels.assertColor(at: CGPoint(x: 25, y: 30), equals: Colors.red, "要素の範囲に画像を描く")
        for point in [CGPoint(x: 5, y: 30), CGPoint(x: 45, y: 30), CGPoint(x: 25, y: 15), CGPoint(x: 25, y: 45)] {
            pixels.assertColor(at: point, equals: Colors.clear, "要素の範囲の外には描かない")
        }
    }

    /// 今の挙動を固定する。透明度は、線・台・白系3種の塗りにかかり、画像本体にだけかからない
    /// （画像本体を描く `UIImage.draw(in:)` は、描画先の透明度によらず不透明度 1 で描く）。
    /// 今の UI に透明度を変える操作は見当たらず、保存データの値だけで生じる（README の残件、第24回）。
    func test_draw_opacity_skipsImageBody() throws {
        let image = solidImage(.blue, CGSize(width: 100, height: 100))
        let simple = makeFramedElement(style: .simple)
        simple.opacity = 0.5
        let white = makeFramedElement(style: .softWhite)
        white.opacity = 0.5

        let simplePixels = try Pixels(render(Self.canvasSize) {
            ImageElementRenderer.draw(simple, in: $0, image: image)
        })
        let whitePixels = try Pixels(render(Self.canvasSize) {
            ImageElementRenderer.draw(white, in: $0, image: image)
        })

        // 画像の青の上に、赤の線を不透明度 0.5 で重ねた色
        simplePixels.assertColor(at: offset(CGPoint(x: 5, y: 50), by: simple), equals: [128, 0, 128, 255], tolerance: 3,
                                 "線には透明度がかかる")
        simplePixels.assertColor(at: offset(CGPoint(x: 50, y: 50), by: simple), equals: Colors.blue,
                                 "画像本体には透明度がかからない")
        // 赤を白へ 72% 寄せた色を、不透明度 0.92 × 0.5 で画像の青の上に重ねた色
        whitePixels.assertColor(at: offset(CGPoint(x: 6, y: 50), by: white), equals: [117, 85, 222, 255], tolerance: 3,
                                "白系の塗りには透明度がかかる")
        whitePixels.assertColor(at: offset(CGPoint(x: 50, y: 50), by: white), equals: Colors.blue,
                                "白系でも、画像本体には透明度がかからない")
    }

    func test_draw_rotatesAroundCenter() throws {
        // 左半分が赤、右半分が青の画像。要素の中心は (40, 40)。
        let element = makeElement(frame: CGRect(x: 20, y: 30, width: 40, height: 20))
        let image = halvesImage(left: .red, right: .blue, size: CGSize(width: 40, height: 20))

        let upright = try Pixels(render(CGSize(width: 80, height: 80)) {
            ImageElementRenderer.draw(element, in: $0, image: image)
        })
        upright.assertColor(at: CGPoint(x: 30, y: 40), equals: Colors.red, "回転なし: 左半分は赤")
        upright.assertColor(at: CGPoint(x: 50, y: 40), equals: Colors.blue, "回転なし: 右半分は青")

        element.rotation = .pi / 2
        let rotated = try Pixels(render(CGSize(width: 80, height: 80)) {
            ImageElementRenderer.draw(element, in: $0, image: image)
        })
        // 下向きが正の画面の座標で、時計回りに 90°。左半分は中心の上へ、右半分は下へ移り、中心は動かない。
        rotated.assertColor(at: CGPoint(x: 40, y: 28), equals: Colors.red, "左半分は中心の上へ移る")
        rotated.assertColor(at: CGPoint(x: 40, y: 52), equals: Colors.blue, "右半分は中心の下へ移る")
        rotated.assertColor(at: CGPoint(x: 25, y: 40), equals: Colors.clear, "回転のあとは、中心の左の外側に描かない")
        rotated.assertColor(at: CGPoint(x: 55, y: 40), equals: Colors.clear, "回転のあとは、中心の右の外側に描かない")
    }

    func test_draw_roundedCorners_clipImage() throws {
        let element = makeElement(frame: CGRect(x: 10, y: 10, width: 40, height: 40))
        element.cornerRadius = 12
        let image = solidImage(.green, CGSize(width: 40, height: 40))

        for rounded in [true, false] {
            element.roundedCorners = rounded
            let pixels = try Pixels(render(CGSize(width: 60, height: 60)) {
                ImageElementRenderer.draw(element, in: $0, image: image)
            })
            pixels.assertColor(at: CGPoint(x: 11, y: 11), equals: rounded ? Colors.clear : Colors.green,
                               "角は、角丸のときだけ切り抜く（角丸: \(rounded)）")
            pixels.assertColor(at: CGPoint(x: 11, y: 30), equals: Colors.green, "辺の中央は切り抜かない（角丸: \(rounded)）")
            pixels.assertColor(at: CGPoint(x: 30, y: 30), equals: Colors.green, "中心は画像（角丸: \(rounded)）")
        }
    }

    func test_draw_frameStyles_drawFrameLayers() throws {
        XCTAssertEqual(Set(FrameCase.all.map(\.style)), Set(ImageFrameStyle.allCases), "11種すべてを確かめる")
        let image = solidImage(.blue, CGSize(width: 100, height: 100))

        for frameCase in FrameCase.all {
            for showFrame in [true, false] {
                let element = makeElement(frame: CGRect(x: 10, y: 10, width: 100, height: 100))
                element.showFrame = showFrame
                element.frameStyle = frameCase.style
                element.frameColor = .red
                element.frameWidth = frameCase.frameWidth
                let pixels = try Pixels(render(CGSize(width: 120, height: 120), background: Colors.grayFill) {
                    ImageElementRenderer.draw(element, in: $0, image: image)
                })

                let label = "\(frameCase.style.rawValue)（フレーム: \(showFrame)）"
                pixels.assertColor(at: offset(CGPoint(x: 50, y: 50), by: element), equals: Colors.blue,
                                   "\(label): 中心は画像（背面のフレームに隠れない）")
                for check in frameCase.checks {
                    pixels.assertColor(at: offset(check.point, by: element), equals: showFrame ? check.color : Colors.blue,
                                       "\(label): \(check.name)。フレームなしなら画像")
                }
            }
        }
    }

    /// 指定したフレームの色で描く。赤だけで確かめると、指定の色を無視して赤で描く不具合を見逃すため、緑で確かめる。
    /// 色を使う10種（film は色を使わない）で、要素の色を使う線・台・塗り・発光の影のすべてを見る。
    func test_draw_frameStyles_useFrameColor() throws {
        XCTAssertEqual(Set(FrameColorCase.all.map(\.style)), Set(ImageFrameStyle.allCases).subtracting([.film]),
                       "色を使う10種すべてを確かめる")
        let image = solidImage(.blue, CGSize(width: 100, height: 100))

        for colorCase in FrameColorCase.all {
            let element = makeFramedElement(style: colorCase.style)
            element.frameColor = UIColor.green.withAlphaComponent(colorCase.frameAlpha)
            element.frameWidth = colorCase.frameWidth
            let pixels = try Pixels(render(Self.canvasSize, background: Colors.grayFill) {
                ImageElementRenderer.draw(element, in: $0, image: image)
            })

            let label = "\(colorCase.style.rawValue)（緑・不透明度 \(colorCase.frameAlpha)）"
            for check in colorCase.checks {
                pixels.assertColor(at: offset(check.point, by: element), equals: check.color, "\(label): \(check.name)")
            }
            if let glowPoint = colorCase.glowPoint {
                // 発光の影は、ぼかしの強さを式から求めにくいため、強さは見ない。灰色の背景の上で、緑だけが明るくなり、
                // 赤と青は同じだけ暗くなる（緑を灰色に重ねた色の並び）ことを確かめる。影が赤なら、赤が明るくなる。
                let point = offset(glowPoint, by: element)
                let glow = pixels.rgba(x: Int(point.x), y: Int(point.y))
                XCTAssertGreaterThanOrEqual(glow[1] - 128, 15, "\(label): 発光の影で、緑は灰色より明るくなる（実際: \(glow)）")
                XCTAssertGreaterThanOrEqual(128 - glow[0], 15, "\(label): 発光の影で、赤は灰色より暗くなる（実際: \(glow)）")
                XCTAssertLessThanOrEqual(abs(glow[0] - glow[2]), 3, "\(label): 発光の影で、赤と青は同じだけ暗くなる（実際: \(glow)）")
            }
        }
    }

    func test_draw_hiddenOrWithoutImage_drawsNothing() throws {
        // 中心・simple の前面の線・白系の塗り・polaroid の背面の余白の位置（要素の左上からの位置）
        let points = [CGPoint(x: 50, y: 50), CGPoint(x: 5, y: 50), CGPoint(x: 6, y: 50), CGPoint(x: 8, y: 50)]
        let image = solidImage(.blue, CGSize(width: 100, height: 100))

        for style in [ImageFrameStyle.simple, .softWhite, .polaroid] {
            let element = makeFramedElement(style: style)

            element.isVisible = false
            let hidden = try Pixels(render(CGSize(width: 120, height: 120)) {
                ImageElementRenderer.draw(element, in: $0, image: image)
            })
            element.isVisible = true
            let withoutImage = try Pixels(render(CGSize(width: 120, height: 120)) {
                ImageElementRenderer.draw(element, in: $0, image: nil)
            })

            for point in points {
                hidden.assertColor(at: offset(point, by: element), equals: Colors.clear,
                                   "\(style.rawValue): 非表示なら、画像もフレームも描かない")
                withoutImage.assertColor(at: offset(point, by: element), equals: Colors.clear,
                                         "\(style.rawValue): 画像がなければ、フレームも描かない")
            }
        }
    }

    func test_draw_restoresCallerState() throws {
        // 描画の中で変える状態（座標変換・透明度・角丸の切り抜き・発光の影）をすべて使う要素
        let element = makeElement(frame: CGRect(x: 2, y: 2, width: 12, height: 12))
        element.rotation = 0.4
        element.opacity = 0.6
        element.showFrame = true
        element.frameStyle = .neon
        element.frameColor = .red
        element.frameWidth = 2
        element.roundedCorners = true
        element.cornerRadius = 4
        let image = solidImage(.blue, CGSize(width: 12, height: 12))
        var before: (transform: CGAffineTransform, clip: CGRect)?
        var after: (transform: CGAffineTransform, clip: CGRect)?

        let pixels = try Pixels(render(CGSize(width: 100, height: 100)) { context in
            // 保存の合成と同じく、呼び出す前に拡大・平行移動・切り抜きを設定し、透明度も変えておく。
            context.scaleBy(x: 2, y: 2)
            context.translateBy(x: 5, y: 5)
            context.clip(to: CGRect(x: 0, y: 0, width: 36, height: 36))
            context.setAlpha(0.5)
            before = (context.ctm, context.boundingBoxOfClipPath)
            ImageElementRenderer.draw(element, in: context, image: image)
            after = (context.ctm, context.boundingBoxOfClipPath)
            // 呼び出しのあとの塗りにも、呼び出す前の変換・切り抜き・透明度がかかる。
            context.setFillColor(UIColor.green.cgColor)
            context.fill(CGRect(x: 30, y: 30, width: 10, height: 10))
        })

        let saved = try XCTUnwrap(before)
        let restored = try XCTUnwrap(after)
        XCTAssertEqual(restored.transform, saved.transform, "座標変換を、呼び出す前の状態に戻す")
        XCTAssertEqual(restored.clip, saved.clip, "切り抜きを、呼び出す前の状態に戻す")
        // 塗りは (30, 30)〜(40, 40)。切り抜きで (36, 36) までになり、拡大と平行移動で画素では (70, 70)〜(82, 82) になる。
        pixels.assertColor(at: CGPoint(x: 75, y: 75), equals: [0, 128, 0, 128], tolerance: 3,
                           "透明度を、呼び出す前の状態（0.5）に戻す")
        pixels.assertColor(at: CGPoint(x: 86, y: 75), equals: Colors.clear, "呼び出す前の切り抜きの外には塗らない")
    }

    // MARK: - 入口

    func test_canvasEntry_matchesDirectDrawing() throws {
        for entry in EntryCase.all {
            let element = makeEntryElement(entry)
            let renderSessions = RenderSessionSpy(drawing: Images.blue)
            let canvas = try Pixels(render(Self.canvasSize) {
                element.drawOnCanvas(in: $0, renderSessions: renderSessions)
            })
            let direct = try Pixels(render(Self.canvasSize) {
                ImageElementRenderer.draw(element, in: $0, image: Images.blue)
            })

            canvas.assertSame(as: direct, "キャンバスの描き方: \(entry.name)")
            for check in entry.checks {
                canvas.assertColor(at: offset(check.point, by: element), equals: check.overClear, tolerance: check.tolerance,
                                   "キャンバスの描き方: \(entry.name)の\(check.name)")
            }
        }
    }

    func test_deleteEntry_matchesDirectDrawing() throws {
        for entry in EntryCase.all {
            let element = makeEntryElement(entry)
            let renderSessions = RenderSessionSpy(drawing: Images.blue)
            let snapshot = try Pixels(XCTUnwrap(element.renderSnapshot(renderSessions: renderSessions)))
            // スナップショットは要素の大きさで、要素の左上を原点にして描く。
            let direct = try Pixels(render(element.size) {
                $0.translateBy(x: -element.position.x, y: -element.position.y)
                ImageElementRenderer.draw(element, in: $0, image: Images.blue)
            })

            snapshot.assertSame(as: direct, "削除エフェクト: \(entry.name)")
            for check in entry.checks {
                snapshot.assertColor(at: check.point, equals: check.overClear, tolerance: check.tolerance,
                                     "削除エフェクト: \(entry.name)の\(check.name)")
            }
        }
    }

    func test_compositeEntry_matchesDirectDrawing() throws {
        for entry in EntryCase.all {
            let element = makeEntryElement(entry)
            element.imageRole = .overlay
            element.zIndex = 110
            // キャンバス全体を覆う不透明なベース。背景の設定は、ベースで隠れて出力に出ない。
            let base = makeElement(frame: CGRect(origin: .zero, size: Self.canvasSize))
            base.imageRole = .base
            base.zIndex = 100
            let project = LogoProject(canvasSize: Self.canvasSize)
            project.elements = [base, element]
            let images = FixedSaveImages()
            images.set(Images.gray, for: base)
            images.set(Images.blue, for: element)

            let composite = try Pixels(XCTUnwrap(
                ImageProcessingService().makeCompositeImage(baseElement: base, project: project, images: images)
            ))
            let direct = try Pixels(render(Self.canvasSize) {
                ImageElementRenderer.draw(base, in: $0, image: Images.gray)
                ImageElementRenderer.draw(element, in: $0, image: Images.blue)
            })

            composite.assertSame(as: direct, "保存の合成: \(entry.name)")
            for check in entry.checks {
                composite.assertColor(at: offset(check.point, by: element), equals: check.overGray, tolerance: check.tolerance,
                                      "保存の合成: \(entry.name)の\(check.name)")
            }
        }
    }

    // MARK: - Helpers

    private static let canvasSize = CGSize(width: 120, height: 120)

    /// 描画に使う値だけを決めた画像要素。画像は描画に直接渡すため、取得先と描画サービスは使わない。
    private func makeElement(frame: CGRect) -> ImageElement {
        let placeholder = snapshotImage(.black)
        let element = ImageElement(
            source: .data(Data([1])), size: nil,
            sourceResolver: FixedImageSourceResolver(image: placeholder),
            previewService: FixedPreviewService(output: placeholder)
        )
        element.position = frame.origin
        element.size = frame.size
        return element
    }

    /// 赤・幅10のフレームを付け、キャンバスの (10, 10) に 100×100 で置いた要素
    private func makeFramedElement(style: ImageFrameStyle) -> ImageElement {
        let element = makeElement(frame: CGRect(x: 10, y: 10, width: 100, height: 100))
        element.showFrame = true
        element.frameStyle = style
        element.frameColor = .red
        element.frameWidth = 10
        return element
    }

    /// 入口で描く要素
    private func makeEntryElement(_ entry: EntryCase) -> ImageElement {
        let element = makeFramedElement(style: entry.style)
        entry.configure(element)
        return element
    }

    /// 要素の左上からの位置を、描いた画像の位置にする。
    private func offset(_ point: CGPoint, by element: ImageElement) -> CGPoint {
        CGPoint(x: point.x + element.position.x, y: point.y + element.position.y)
    }

    /// UIGraphicsImageRenderer の描画ブロックの中で描く（渡す context が UIKit の現在の描画先になる）。
    /// 形式は、削除エフェクトと保存の合成と同じ（倍率1・透明あり）。
    private func render(_ size: CGSize, background: UIColor? = nil, _ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            if let background {
                background.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            draw(context.cgContext)
        }
    }
}

// MARK: - 期待する色

/// 期待する色（RGBA、乗算済み、0〜255）。フレームの色は、描画の式からテストの中で計算した値。
private enum Colors {
    static let clear = [0, 0, 0, 0]
    static let red = [255, 0, 0, 255]
    static let green = [0, 255, 0, 255]
    static let blue = [0, 0, 255, 255]
    static var grayFill: UIColor { UIColor(red: 128 / 255, green: 128 / 255, blue: 128 / 255, alpha: 1) }
    /// polaroid の台紙：赤を白へ 92% 寄せた色
    static let polaroidPaper = [255, 235, 235, 255]
    /// film の台：白 8%
    static let filmBase = [20, 20, 20, 255]
    /// badge の台：赤を白へ 80% 寄せた色を、不透明度 0.92 で灰色の上に重ねた色
    static let badgeOverGray = [245, 198, 198, 255]
    /// stamp の台紙：赤をクリーム色（0.97, 0.95, 0.88）へ 90% 寄せた色
    static let stampPaper = [248, 218, 202, 255]
    /// 白系3種の塗り：赤を白へ 72% 寄せた色を、不透明度 0.92 で画像の青の上に重ねた色
    static let whiteRingOverBlue = [235, 169, 189, 255]
}

/// 入口の確認に使う画像
private enum Images {
    static let blue = solidImage(.blue, CGSize(width: 100, height: 100))
    static let gray = solidImage(Colors.grayFill, CGSize(width: 120, height: 120))
}

/// フレームの種類ごとに、フレームが見える点（要素の左上からの位置）と、そこに描かれる色。
/// 赤のフレーム・青の画像・灰色の背景で計算する。どの点も、線と余白の境目から1画素以上離す。
private struct FrameCase {
    struct Check {
        let name: String
        let point: CGPoint
        let color: [Int]
    }

    let style: ImageFrameStyle
    var frameWidth: CGFloat = 10
    let checks: [Check]

    static let all: [FrameCase] = [
        FrameCase(style: .simple, checks: [Check(name: "前面の線", point: CGPoint(x: 5, y: 50), color: Colors.red)]),
        FrameCase(style: .double, checks: [Check(name: "外側の線", point: CGPoint(x: 2, y: 50), color: Colors.red)]),
        FrameCase(style: .cornerAccent, checks: [Check(name: "角の線", point: CGPoint(x: 5, y: 15), color: Colors.red)]),
        // 発光の影が中心の画像に届かないよう、neon だけ幅を細くする。
        FrameCase(style: .neon, frameWidth: 4,
                  checks: [Check(name: "発光の線", point: CGPoint(x: 3, y: 50), color: Colors.red)]),
        FrameCase(style: .polaroid,
                  checks: [Check(name: "背面の台紙の余白", point: CGPoint(x: 8, y: 50), color: Colors.polaroidPaper)]),
        FrameCase(style: .film, checks: [Check(name: "背面の台の余白", point: CGPoint(x: 8, y: 50), color: Colors.filmBase)]),
        FrameCase(style: .badge, checks: [
            Check(name: "前面の線", point: CGPoint(x: 2, y: 50), color: Colors.red),
            Check(name: "背面の台の余白", point: CGPoint(x: 10, y: 50), color: Colors.badgeOverGray),
        ]),
        FrameCase(style: .stamp,
                  checks: [Check(name: "背面の台紙の余白", point: CGPoint(x: 11, y: 50), color: Colors.stampPaper)]),
        FrameCase(style: .softWhite, checks: [Check(name: "塗り", point: CGPoint(x: 6, y: 50), color: Colors.whiteRingOverBlue)]),
        FrameCase(style: .glassWhite, checks: [Check(name: "塗り", point: CGPoint(x: 6, y: 50), color: Colors.whiteRingOverBlue)]),
        FrameCase(style: .editorialWhite,
                  checks: [Check(name: "塗り", point: CGPoint(x: 6, y: 50), color: Colors.whiteRingOverBlue)]),
    ]
}

/// フレームの色を使う10種で、要素の色を使う線・台・塗りが見える点（要素の左上からの位置）と、そこに描かれる色。
/// FrameCase の赤とは別に、緑のフレーム・青の画像・灰色の背景で計算する。点は FrameCase と同じく、線と余白の境目から1画素以上離す。
/// 白系3種は、フレームの色の不透明度を塗りの不透明度に使う（0.08〜0.92 に収める）ため、不透明度 0.5 の緑で確かめる。
private struct FrameColorCase {
    typealias Check = FrameCase.Check

    let style: ImageFrameStyle
    var frameAlpha: CGFloat = 1
    var frameWidth: CGFloat = 10
    let checks: [Check]
    /// 発光の影を見る点。影は線の外側にも出るため、要素の外（灰色の背景の上）で見る。
    var glowPoint: CGPoint?

    static let all: [FrameColorCase] = [
        FrameColorCase(style: .simple, checks: [Check(name: "前面の線", point: CGPoint(x: 5, y: 50), color: Colors.green)]),
        FrameColorCase(style: .double, checks: [
            Check(name: "外側の線", point: CGPoint(x: 2, y: 50), color: Colors.green),
            // 緑を白へ 55% 寄せた色
            Check(name: "内側の線", point: CGPoint(x: 8, y: 50), color: [140, 255, 140, 255]),
        ]),
        FrameColorCase(style: .cornerAccent,
                       checks: [Check(name: "角の線", point: CGPoint(x: 5, y: 15), color: Colors.green)]),
        // 線は FrameCase と同じ点。線は要素の左端の 0.1 外まで描くため、影はそこから 0.9 以上離れた要素の外で見る。
        FrameColorCase(style: .neon, frameWidth: 4,
                       checks: [Check(name: "発光の線", point: CGPoint(x: 3, y: 50), color: Colors.green)],
                       glowPoint: CGPoint(x: -2, y: 50)),
        // 緑を白へ 92% 寄せた色
        FrameColorCase(style: .polaroid,
                       checks: [Check(name: "背面の台紙の余白", point: CGPoint(x: 8, y: 50), color: [235, 255, 235, 255])]),
        FrameColorCase(style: .badge, checks: [
            Check(name: "前面の線", point: CGPoint(x: 2, y: 50), color: Colors.green),
            // 緑を白へ 80% 寄せた色を、不透明度 0.92 で灰色の上に重ねた色
            Check(name: "背面の台の余白", point: CGPoint(x: 10, y: 50), color: [198, 245, 198, 255]),
        ]),
        FrameColorCase(style: .stamp, checks: [
            // 緑を黒へ 16% 寄せた色。線は揺らいでいて、y = 50 では中心が x ≈ 3.2 にある。
            // 線の上に重ねる黒の破線（中心から 1.2 まで）を避けて、x = 5 で見る。
            Check(name: "前面の線", point: CGPoint(x: 5, y: 50), color: [0, 214, 0, 255]),
            // 緑をクリーム色（0.97, 0.95, 0.88）へ 90% 寄せた色
            Check(name: "背面の台紙の余白", point: CGPoint(x: 11, y: 50), color: [223, 244, 202, 255]),
        ]),
        whiteCase(.softWhite),
        whiteCase(.glassWhite),
        whiteCase(.editorialWhite),
    ]

    /// 緑を白へ 72% 寄せた色を、フレームの色の不透明度 0.5 で画像の青の上に重ねた色
    private static func whiteCase(_ style: ImageFrameStyle) -> FrameColorCase {
        FrameColorCase(style: style, frameAlpha: 0.5,
                       checks: [Check(name: "塗り", point: CGPoint(x: 6, y: 50), color: [92, 128, 219, 255])])
    }
}

/// 入口で描く要素と、入口の出力で単独に確かめる点（要素の左上を原点にした、描いた画像の上の位置）。
/// 透明の上（キャンバスの描き方・削除エフェクト）と、灰色のベースの上（保存の合成）での色を、テストの中で計算しておく。
private struct EntryCase {
    struct Check {
        let name: String
        let point: CGPoint
        let overClear: [Int]
        let overGray: [Int]
        var tolerance = 10
    }

    let name: String
    let style: ImageFrameStyle
    /// フレームの種類のほかに変える値。表を静的に持つため、値を捕まえない処理にする。
    let configure: @Sendable (ImageElement) -> Void
    let checks: [Check]

    static let all: [EntryCase] = [
        // 画像本体には透明度がかからない（今の挙動）。台紙（赤を白へ 92% 寄せた色）には不透明度 0.8 がかかる。
        // 台紙の点は、要素の左上から (8, 50) の点を中心のまわりに 0.3 回した位置で、要素の左上から (9, 37) の画素になる。
        EntryCase(name: "polaroid・回転・角丸・半透明", style: .polaroid, configure: {
            $0.rotation = 0.3
            $0.roundedCorners = true
            $0.cornerRadius = 16
            $0.opacity = 0.8
        }, checks: [
            Check(name: "画像本体", point: CGPoint(x: 50, y: 50), overClear: Colors.blue, overGray: Colors.blue),
            Check(name: "回した台紙", point: CGPoint(x: 9, y: 37), overClear: [204, 188, 188, 204],
                  overGray: [230, 213, 213, 255], tolerance: 6),
        ]),
        whiteCase(.softWhite),
        whiteCase(.glassWhite),
        whiteCase(.editorialWhite),
    ]

    /// 白系3種は、現在の描画先に描く塗りと、画像本体を確かめる。
    private static func whiteCase(_ style: ImageFrameStyle) -> EntryCase {
        EntryCase(name: style.rawValue, style: style, configure: { _ in }, checks: [
            Check(name: "画像本体", point: CGPoint(x: 50, y: 50), overClear: Colors.blue, overGray: Colors.blue),
            Check(name: "塗り", point: CGPoint(x: 6, y: 50), overClear: Colors.whiteRingOverBlue,
                  overGray: Colors.whiteRingOverBlue),
        ])
    }
}

/// 要素ごとに決めた画像を返す保存の範囲。加工済みの画像・描画用の画像・元画像のどれにも同じ画像を返す。
private final class FixedSaveImages: SaveImageReading {
    private var images: [ObjectIdentifier: UIImage] = [:]

    func set(_ image: UIImage, for element: ImageElement) {
        images[ObjectIdentifier(element)] = image
    }

    func originalImage(of element: ImageElement) -> UIImage? {
        images[ObjectIdentifier(element)]
    }

    func filteredImage(of element: ImageElement) -> UIImage? {
        images[ObjectIdentifier(element)]
    }

    func drawingImage(of element: ImageElement) -> UIImage? {
        images[ObjectIdentifier(element)]
    }

    /// 背景画像は扱わない（画像要素の描画だけを見る）。
    var backgroundImage: UIImage? { nil }
}

// MARK: - 画素

/// 画像の画素（RGBA、乗算済み、0〜255）。8 ビットの RGB に描き直して読む。
private struct Pixels {
    let width: Int
    let height: Int
    private let buffer: [UInt8]

    init(_ image: UIImage) throws {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let drawn = buffer.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(drawn, "画素を読む描画先を作れない")
        self.width = width
        self.height = height
        self.buffer = buffer
    }

    /// 上からの座標の画素
    func rgba(x: Int, y: Int) -> [Int] {
        let offset = (y * width + x) * 4
        return buffer[offset..<(offset + 4)].map(Int.init)
    }

    func assertColor(
        at point: CGPoint,
        equals expected: [Int],
        tolerance: Int = 10,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = rgba(x: Int(point.x), y: Int(point.y))
        let matches = zip(actual, expected).allSatisfy { abs($0 - $1) <= tolerance }
        XCTAssertTrue(matches, "\(message)（位置: \(point)、期待: \(expected)、実際: \(actual)）", file: file, line: line)
    }

    /// すべての画素が、もう一方の画像と許容差の中で一致する。
    func assertSame(
        as other: Pixels,
        tolerance: Int = 2,
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard width == other.width, height == other.height else {
            return XCTFail("\(message)（大きさが違う: \(width)×\(height) と \(other.width)×\(other.height)）",
                           file: file, line: line)
        }
        var mismatches = 0
        var first: String?
        for y in 0..<height {
            for x in 0..<width {
                let actual = rgba(x: x, y: y)
                let expected = other.rgba(x: x, y: y)
                guard zip(actual, expected).contains(where: { abs($0 - $1) > tolerance }) else { continue }
                mismatches += 1
                if first == nil { first = "(\(x), \(y)) 実際: \(actual)、直接の描画: \(expected)" }
            }
        }
        XCTAssertEqual(mismatches, 0, "\(message)（一致しない画素: \(mismatches) 個。最初: \(first ?? "なし")）",
                       file: file, line: line)
    }
}

// MARK: - 画像

/// 単色の画像（倍率1）
private func solidImage(_ color: UIColor, _ size: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
}

/// 左半分と右半分で色を分けた画像（倍率1）
private func halvesImage(left: UIColor, right: UIColor, size: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: size, format: format).image { context in
        left.setFill()
        context.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height))
        right.setFill()
        context.fill(CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height))
    }
}
