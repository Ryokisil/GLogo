//
// 概要:
// メタデータとメタデータ履歴の永続化を担当するストア。
//

import Foundation
import OSLog

final class MetadataFileStore {
    private let logger = Logger(subsystem: "com.silvia.GLogo", category: "MetadataStore")

    /// メタデータを識別子単位のJSONとして保存する。
    /// - Parameters:
    ///   - metadata: 保存対象のメタデータ。
    ///   - identifier: 保存先ファイル名に使用する画像識別子。
    /// - Returns: 保存に成功した場合は `true`、失敗時は `false`。
    func saveMetadata(_ metadata: ImageMetadata, for identifier: String) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(metadata)

            guard let baseURL = metadataDirectoryURL() else {
                return false
            }
            try createDirectoryIfNeeded(at: baseURL)

            let fileURL = baseURL.appendingPathComponent("metadata_\(identifier).json")
            try data.write(to: fileURL)
            return true
        } catch {
            logger.warning("メタデータ保存に失敗: identifier=\(identifier, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 識別子に対応するメタデータJSONを読み込む。
    /// - Parameters:
    ///   - identifier: 読み込む画像識別子。
    /// - Returns: 読み込み成功時は `ImageMetadata`、存在しない/失敗時は `nil`。
    func loadMetadata(for identifier: String) -> ImageMetadata? {
        do {
            guard let baseURL = metadataDirectoryURL() else {
                return nil
            }
            let fileURL = baseURL.appendingPathComponent("metadata_\(identifier).json")
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }

            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ImageMetadata.self, from: data)
        } catch {
            logger.warning("メタデータ読込に失敗: identifier=\(identifier, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// メタデータ編集履歴を識別子単位のJSONとして保存する。
    /// - Parameters:
    ///   - history: 保存対象の編集履歴配列。
    ///   - identifier: 保存先ファイル名に使用する画像識別子。
    /// - Returns: 保存に成功した場合は `true`、失敗時は `false`。
    func saveEditHistory(_ history: [MetadataEditOperation], for identifier: String) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)

            guard let baseURL = historyDirectoryURL() else {
                return false
            }
            try createDirectoryIfNeeded(at: baseURL)

            let fileURL = baseURL.appendingPathComponent("history_\(identifier).json")
            try data.write(to: fileURL)
            return true
        } catch {
            logger.warning("履歴保存に失敗: identifier=\(identifier, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// 識別子に対応するメタデータ編集履歴JSONを読み込む。
    /// - Parameters:
    ///   - identifier: 読み込む画像識別子。
    /// - Returns: 読み込み成功時は履歴配列、存在しない/失敗時は `nil`。
    func loadEditHistory(for identifier: String) -> [MetadataEditOperation]? {
        do {
            guard let baseURL = historyDirectoryURL() else {
                return nil
            }
            let fileURL = baseURL.appendingPathComponent("history_\(identifier).json")
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }

            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([MetadataEditOperation].self, from: data)
        } catch {
            logger.warning("編集履歴の読み込みに失敗: identifier=\(identifier, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// メタデータ保存ディレクトリURLを返す。
    /// - Parameters: なし
    /// - Returns: 取得できた場合はディレクトリURL、失敗時は `nil`。
    private func metadataDirectoryURL() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent("GLogo/Metadata")
    }

    /// 履歴保存ディレクトリURLを返す。
    /// - Parameters: なし
    /// - Returns: 取得できた場合はディレクトリURL、失敗時は `nil`。
    private func historyDirectoryURL() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent("GLogo/History")
    }

    /// 対象ディレクトリが存在しない場合に作成する。
    /// - Parameters:
    ///   - url: 作成確認対象のディレクトリURL。
    /// - Returns: なし
    /// - Throws: ディレクトリ作成に失敗した場合のエラー。
    private func createDirectoryIfNeeded(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
