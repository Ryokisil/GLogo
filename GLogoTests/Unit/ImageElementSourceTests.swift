// 画像要素の差し替え（replaceImageSource）と復元（restoreImageSource）が、ソース・識別子・高画質化済みの値
// （差し替えでは、引数に応じて編集値も）だけを変え、配置サイズを変えず、元画像を取得しないことを固定する（第23回）。
// 配置サイズを合わせ直すのは呼び出し側の役目で、本番の呼び出し元（差し替えのイベント）はサイズを変えない。

import UIKit
import XCTest
@testable import GLogo

final class ImageElementSourceTests: XCTestCase {
    private let keptSize = CGSize(width: 77, height: 33)

    /// 差し替えは、画像として読めるかによらず配置サイズを変えない。ソースはデータだけにし、識別子と高画質化済みの値は引数のとおり。
    /// 編集値は、戻す指定のときだけ初期状態へ戻し、戻さない指定では変更済みの30項目を残す。
    func test_replaceSource_keepsSizeAndEditValues() throws {
        let replacements: [(String, Data)] = [
            ("縦横比の違う画像", try pngData(size: CGSize(width: 20, height: 40))),
            ("デコードできないデータ", Data([0, 1, 2, 3])),
            ("空のデータ", Data())
        ]
        for (label, data) in replacements {
            for resetsAdjustments in [false, true] {
                let caseLabel = "\(label)・編集値を\(resetsAdjustments ? "戻す" : "残す")"
                let (element, resolver) = makeElement()
                let initial = ImageEditStateRecord(element)
                ImageEditStateRecord.applyDistinctValues(to: element)
                let edited = ImageEditStateRecord(element)
                XCTAssertNotEqual(edited, initial, "\(caseLabel)：前提として編集値を変えておく")
                fillAllSources(of: element)
                element.originalImageIdentifier = "old"
                element.hasAppliedUpscale = false

                element.replaceImageSource(
                    with: data, resetAdjustments: resetsAdjustments, originalIdentifier: "given", hasAppliedUpscale: true
                )

                XCTAssertEqual(element.size, keptSize, caseLabel)
                XCTAssertEqual(SourceValues(element), SourceValues(data: data), "\(caseLabel)：ソースはデータだけ")
                XCTAssertEqual(element.originalImageIdentifier, "given", caseLabel)
                XCTAssertTrue(element.hasAppliedUpscale, caseLabel)
                XCTAssertEqual(ImageEditStateRecord(element), resetsAdjustments ? initial : edited, caseLabel)
                XCTAssertEqual(resolver.originalCalls, 0, "\(caseLabel)：差し替えでは元画像を取得しない")
            }
        }
    }

    /// 識別子を渡さない差し替えは、新しい識別子を作る（以前の識別子を残さない）。高画質化済みの値は既定の false にする。
    func test_replaceSource_withoutIdentifier_generatesNew() throws {
        let (element, _) = makeElement()
        element.originalImageIdentifier = "old"
        element.hasAppliedUpscale = true

        element.replaceImageSource(with: try pngData(size: CGSize(width: 20, height: 40)), resetAdjustments: false)

        let identifier = try XCTUnwrap(element.originalImageIdentifier)
        XCTAssertNotEqual(identifier, "old")
        XCTAssertFalse(element.hasAppliedUpscale)
        XCTAssertEqual(element.size, keptSize)
    }

    /// 復元は取得先を呼ばず、配置サイズを変えない。ソースは優先順位（パス > URL > ファイル名 > データ）の1つだけにし、
    /// 古いソース・識別子・高画質化済みの値を残さない。毎回4つのソースと識別子・高画質化済みの値を入れた状態から始め、
    /// 上位のソースを1つずつ外した組み合わせで、下位のソース同士の取り違えも見る。
    func test_restoreSource_keepsSizeWithoutFetching() throws {
        let data = Data([7])
        let fileName = "restored-name"
        let fileURL = URL(fileURLWithPath: "/restored/url.png")
        let otherURL = try XCTUnwrap(URL(string: "https://example.com/restored.png"))
        let path = "/restored/path.png"
        let cases = [
            RestoreCase("すべて", SourceValues(data: data, fileName: fileName, url: fileURL, path: path), SourceValues(path: path)),
            RestoreCase("パスなし", SourceValues(data: data, fileName: fileName, url: fileURL), SourceValues(url: fileURL)),
            RestoreCase("パスと URL なし", SourceValues(data: data, fileName: fileName), SourceValues(fileName: fileName)),
            RestoreCase("データだけ", SourceValues(data: data), SourceValues(data: data)),
            RestoreCase("パスだけ", SourceValues(path: path), SourceValues(path: path)),
            RestoreCase("ファイル URL だけ", SourceValues(url: fileURL), SourceValues(url: fileURL)),
            RestoreCase("ファイル以外の URL だけ", SourceValues(url: otherURL), SourceValues(url: otherURL)),
            RestoreCase("ファイル名だけ", SourceValues(fileName: fileName), SourceValues(fileName: fileName)),
            RestoreCase("なし", SourceValues(), SourceValues(), identifier: nil)
        ]
        for restoreCase in cases {
            for (startsUpscaled, restoresUpscaled) in [(true, false), (false, true)] {
                let caseLabel = "\(restoreCase.label)・高画質化済み \(startsUpscaled) → \(restoresUpscaled)"
                let (element, resolver) = makeElement()
                fillAllSources(of: element)
                element.originalImageIdentifier = "old"
                element.hasAppliedUpscale = startsUpscaled
                let input = restoreCase.input

                element.restoreImageSource(
                    imageData: input.data, fileName: input.fileName, url: input.url, path: input.path,
                    originalIdentifier: restoreCase.identifier, hasAppliedUpscale: restoresUpscaled
                )

                XCTAssertEqual(resolver.originalCalls, 0, "\(caseLabel)：復元では元画像を取得しない")
                XCTAssertEqual(element.size, keptSize, caseLabel)
                XCTAssertEqual(SourceValues(element), restoreCase.expected, caseLabel)
                XCTAssertEqual(element.originalImageIdentifier, restoreCase.identifier, caseLabel)
                XCTAssertEqual(element.hasAppliedUpscale, restoresUpscaled, caseLabel)
            }
        }
    }

    // MARK: - Helpers

    /// 4つのソースの値。どれが残ったかを、まとめて比べる。
    private struct SourceValues: Equatable {
        var data: Data?
        var fileName: String?
        var url: URL?
        var path: String?

        init(data: Data? = nil, fileName: String? = nil, url: URL? = nil, path: String? = nil) {
            self.data = data
            self.fileName = fileName
            self.url = url
            self.path = path
        }

        init(_ element: ImageElement) {
            self.init(
                data: element.imageData, fileName: element.imageFileName,
                url: element.originalImageURL, path: element.originalImagePath
            )
        }
    }

    /// 復元に渡すソースと、復元のあとに残るはずのソース。識別子は、既定では "restored" を渡す。
    private struct RestoreCase {
        let label: String
        let input: SourceValues
        let expected: SourceValues
        let identifier: String?

        init(_ label: String, _ input: SourceValues, _ expected: SourceValues, identifier: String? = "restored") {
            self.label = label
            self.input = input
            self.expected = expected
            self.identifier = identifier
        }
    }

    /// 配置サイズが 77x33 の画像要素と、その取得先（配置サイズと縦横比の違う画像を返す）。
    private func makeElement() -> (ImageElement, CountingSource) {
        let resolver = CountingSource()
        let element = ImageElement(
            source: .data(Data([1])), size: keptSize, sourceResolver: resolver, previewService: ImagePreviewService.shared
        )
        return (element, resolver)
    }

    /// 古い値が残らないことを見るため、4つのソースをすべて入れておく（保存データの復元では、複数のキーが入りうる）。
    private func fillAllSources(of element: ImageElement) {
        element.imageData = Data([9])
        element.imageFileName = "old-name"
        element.originalImageURL = URL(fileURLWithPath: "/old/url.png")
        element.originalImagePath = "/old/path.png"
    }

    private func pngData(size: CGSize) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return try XCTUnwrap(image.pngData())
    }
}

/// 元画像の取得の回数を数え、どのソースにも配置サイズと縦横比の違う画像（40x10）を返す取得先。
/// テストのスレッドから同期にだけ呼ばれる。
private final class CountingSource: ImageSourceResolving, @unchecked Sendable {
    private let image: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 40, height: 10), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 10))
        }
    }()
    private(set) var originalCalls = 0

    func resolveOriginalImage(imageData: Data?, fileName: String?, url: URL?, path: String?) -> UIImage? {
        originalCalls += 1
        return image
    }

    func resolveEditingImage(
        identifier: String?,
        fileName: String?,
        originalPath: String?,
        originalImageProvider: () -> UIImage?,
        proxyTargetLongSide: CGFloat,
        highResThresholdMP: CGFloat
    ) -> UIImage? {
        nil
    }
}
