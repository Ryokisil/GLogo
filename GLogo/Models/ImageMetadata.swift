// 画像要素が保持するメタデータ（作成情報・EXIF・追加情報）を表す。

import Foundation

/// 画像メタデータを表す構造体
struct ImageMetadata: Codable {
    // 基本メタデータ
    var creationDate: Date?
    var modificationDate: Date?
    var author: String?
    var description: String?
    var copyright: String?
    var keywords: [String]
    var title: String?

    // EXIF情報
    var cameraMake: String?
    var cameraModel: String?
    var focalLength: Double?
    var aperture: Double?
    var shutterSpeed: Double?
    var iso: Int?
    var flash: Bool?
    var longitude: Double?
    var latitude: Double?
    var altitude: Double?

    // その他のメタデータ（汎用的なDictionary形式で保存）
    var additionalMetadata: [String: String]

    init(
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        author: String? = nil,
        description: String? = nil,
        copyright: String? = nil,
        keywords: [String] = [],
        title: String? = nil,
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        focalLength: Double? = nil,
        aperture: Double? = nil,
        shutterSpeed: Double? = nil,
        iso: Int? = nil,
        flash: Bool? = nil,
        longitude: Double? = nil,
        latitude: Double? = nil,
        altitude: Double? = nil,
        additionalMetadata: [String: String] = [:]
    ) {
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.author = author
        self.description = description
        self.copyright = copyright
        self.keywords = keywords
        self.title = title
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.focalLength = focalLength
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
        self.iso = iso
        self.flash = flash
        self.longitude = longitude
        self.latitude = latitude
        self.altitude = altitude
        self.additionalMetadata = additionalMetadata
    }
}
