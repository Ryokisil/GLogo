//
//  ProjectStorage.swift
//  GameLogoMaker
//
//  概要:
//  このファイルはロゴプロジェクトのデータ保存と読み込みを担当するユーティリティクラスです。
//  プロジェクトの保存、読み込み、一覧取得、削除などの機能を提供します。
//  FileManagerを使用してアプリのドキュメントディレクトリにJSONファイルとして保存します。
//  また、プロジェクト関連のアセット（画像など）の管理も行います。
//

import Foundation
import UIKit
import OSLog

/// プロジェクト保存エラーの種類
enum ProjectStorageError: Error {
    case encodingFailed
    case saveFailed
    case loadFailed
    case projectNotFound
    case directoryCreationFailed
}

/// プロジェクトストレージ - プロジェクトの保存と読み込みを管理
final class ProjectStorage: Sendable {
    /// シングルトンインスタンス
    static let shared = ProjectStorage()
    private let logger = Logger(subsystem: "com.silvia.GLogo", category: "ProjectStorage")
    
    /// プロジェクトディレクトリ名
    private let projectDirectoryName = "Projects"
    
    /// アセットディレクトリ名
    private let assetDirectoryName = "Assets"
    
    /// 初期化
    private init() {
        // プロジェクトディレクトリとアセットディレクトリの作成
        createDirectoriesIfNeeded()
    }
    
    // MARK: - ディレクトリ管理
    
    /// 必要なディレクトリを作成
    private func createDirectoriesIfNeeded() {
        do {
            // プロジェクトディレクトリ
            try createDirectoryIfNeeded(at: projectDirectoryURL)
            
            // アセットディレクトリ
            try createDirectoryIfNeeded(at: assetDirectoryURL)
        } catch {
            logger.error("保存ディレクトリ作成に失敗: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// 指定したURLにディレクトリがなければ作成
    private func createDirectoryIfNeeded(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    /// ドキュメントディレクトリのURL
    private var documentDirectoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// プロジェクトディレクトリのURL
    private var projectDirectoryURL: URL {
        documentDirectoryURL.appendingPathComponent(projectDirectoryName)
    }
    
    /// アセットディレクトリのURL
    private var assetDirectoryURL: URL {
        documentDirectoryURL.appendingPathComponent(assetDirectoryName)
    }
    
    // MARK: - プロジェクト保存
    
    /// プロジェクトを保存
    func saveProject(_ project: LogoProject, completion: @escaping @Sendable (Bool) -> Void) {
        do {
            let jsonData = try Self.makeEncoder().encode(project)
            let projectURL = url(for: project.id)

            DispatchQueue.global(qos: .background).async {
                do {
                    try jsonData.write(to: projectURL)
                    DispatchQueue.main.async { completion(true) }
                } catch {
                    self.logger.error("プロジェクト保存に失敗: id=\(project.id.uuidString, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
                    DispatchQueue.main.async { completion(false) }
                }
            }
        } catch {
            logger.error("プロジェクト保存に失敗: id=\(project.id.uuidString, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async { completion(false) }
        }
    }
    
    /// プロジェクトを非同期で保存（Promise風）
    func saveProject(_ project: LogoProject) async throws {
        let jsonData = try Self.makeEncoder().encode(project)
        let projectURL = url(for: project.id)
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    try jsonData.write(to: projectURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - プロジェクト読み込み
    
    /// プロジェクトを読み込み
    func loadProject(withId id: UUID, completion: @escaping @Sendable (LogoProject?) -> Void) {
        let projectURL = url(for: id)
        DispatchQueue.global(qos: .background).async {
            do {
                let jsonData = try Data(contentsOf: projectURL)
                let project = try Self.makeDecoder().decode(LogoProject.self, from: jsonData)
                DispatchQueue.main.async { completion(project) }
            } catch {
                self.logger.error("プロジェクト読込に失敗: id=\(id.uuidString, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    /// プロジェクトを非同期で読み込み（Promise風）
    func loadProject(withId id: UUID) async throws -> LogoProject {
        let projectURL = url(for: id)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let jsonData = try Data(contentsOf: projectURL)
                    let project = try Self.makeDecoder().decode(LogoProject.self, from: jsonData)
                    continuation.resume(returning: project)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - プロジェクト一覧
    
    /// 保存されているプロジェクト一覧を取得
    func getProjects(completion: @escaping @Sendable ([LogoProject]) -> Void) {
        let projectDirectoryURL = self.projectDirectoryURL
        DispatchQueue.global(qos: .background).async {
            var projects: [LogoProject] = []
            
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: projectDirectoryURL,
                    includingPropertiesForKeys: nil
                )
                
                for fileURL in fileURLs where fileURL.pathExtension == "json" {
                    if let project = try? Self.loadProjectFromURL(fileURL) {
                        projects.append(project)
                    }
                }
                
                projects.sort { $0.updatedAt > $1.updatedAt }
                
                DispatchQueue.main.async { completion(projects) }
            } catch {
                self.logger.error("プロジェクト一覧取得に失敗: \(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }
    
    /// プロジェクトを非同期で一覧取得（Promise風）
    func getProjects() async -> [LogoProject] {
        let projectDirectoryURL = self.projectDirectoryURL
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let fileURLs = try FileManager.default.contentsOfDirectory(
                        at: projectDirectoryURL,
                        includingPropertiesForKeys: nil
                    )
                    var projects: [LogoProject] = []
                    for fileURL in fileURLs where fileURL.pathExtension == "json" {
                        if let project = try? Self.loadProjectFromURL(fileURL) {
                            projects.append(project)
                        }
                    }
                    projects.sort { $0.updatedAt > $1.updatedAt }
                    continuation.resume(returning: projects)
                } catch {
                    self.logger.error("プロジェクト一覧取得に失敗: \(error.localizedDescription, privacy: .public)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // MARK: - プロジェクト削除
    
    /// プロジェクトを削除
    func deleteProject(withId id: UUID, completion: @escaping @Sendable (Bool) -> Void) {
        let projectURL = url(for: id)
        DispatchQueue.global(qos: .background).async {
            do {
                if FileManager.default.fileExists(atPath: projectURL.path) {
                    try FileManager.default.removeItem(at: projectURL)
                    DispatchQueue.main.async { completion(true) }
                } else {
                    DispatchQueue.main.async { completion(false) }
                }
            } catch {
                self.logger.error("プロジェクト削除に失敗: id=\(id.uuidString, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    /// プロジェクトを非同期で削除（Promise風）
    func deleteProject(withId id: UUID) async throws {
        let projectURL = url(for: id)
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    guard FileManager.default.fileExists(atPath: projectURL.path) else {
                        throw ProjectStorageError.projectNotFound
                    }
                    try FileManager.default.removeItem(at: projectURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - アセット管理
    
    /// 画像アセットを保存
    func saveImageAsset(_ image: UIImage, name: String? = nil) -> String? {
        let assetName = name ?? "img_\(UUID().uuidString)"
        let assetURL = assetDirectoryURL.appendingPathComponent("\(assetName).png")
        
        do {
            // 画像をPNGデータに変換
            guard let imageData = image.pngData() else { return nil }
            
            // ファイルに書き込み
            try imageData.write(to: assetURL)
            
            return assetName
        } catch {
            logger.error("画像アセット保存に失敗: name=\(assetName, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
    
    /// 画像アセットを読み込み
    func loadImageAsset(named name: String) -> UIImage? {
        let assetURL = assetDirectoryURL.appendingPathComponent("\(name).png")
        return UIImage(contentsOfFile: assetURL.path)
    }
    
    /// 画像アセットを削除
    func deleteImageAsset(named name: String) -> Bool {
        let assetURL = assetDirectoryURL.appendingPathComponent("\(name).png")
        
        do {
            if FileManager.default.fileExists(atPath: assetURL.path) {
                try FileManager.default.removeItem(at: assetURL)
                return true
            }
            return false
        } catch {
            logger.error("画像アセット削除に失敗: name=\(name, privacy: .public), error=\(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    // MARK: - ヘルパーメソッド
    
    /// プロジェクトIDからファイルURLを取得
    private func url(for projectId: UUID) -> URL {
        return projectDirectoryURL.appendingPathComponent("\(projectId.uuidString).json")
    }
    
    /// URLからプロジェクトを読み込み
    private static func loadProjectFromURL(_ url: URL) throws -> LogoProject {
        let jsonData = try Data(contentsOf: url)
        return try makeDecoder().decode(LogoProject.self, from: jsonData)
    }

    /// JSONEncoder を毎回生成（スレッド競合回避）
    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }

    /// JSONDecoder を毎回生成（スレッド競合回避）
    private static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}
