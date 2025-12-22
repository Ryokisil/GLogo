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

/// プロジェクト保存エラーの種類
enum ProjectStorageError: Error {
    case encodingFailed
    case saveFailed
    case loadFailed
    case projectNotFound
    case directoryCreationFailed
}

/// プロジェクトストレージ - プロジェクトの保存と読み込みを管理
class ProjectStorage {
    /// シングルトンインスタンス
    static let shared = ProjectStorage()
    
    /// プロジェクトディレクトリ名
    private let projectDirectoryName = "Projects"
    
    /// アセットディレクトリ名
    private let assetDirectoryName = "Assets"
    
    /// JSONエンコーダー
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
    
    /// JSONデコーダー
    private let decoder = JSONDecoder()
    
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
            print("Error creating directories: \(error)")
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
    func saveProject(_ project: LogoProject, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            do {
                // プロジェクトをJSONデータに変換
                let jsonData = try self.encoder.encode(project)
                
                // プロジェクトURLを取得
                let projectURL = self.url(for: project.id)
                
                // JSONデータをファイルに書き込み
                try jsonData.write(to: projectURL)
                
                DispatchQueue.main.async { completion(true) }
            } catch {
                print("Failed to save project: \(error)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    /// プロジェクトを非同期で保存（Promise風）
    func saveProject(_ project: LogoProject) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            saveProject(project) { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ProjectStorageError.saveFailed)
                }
            }
        }
    }
    
    // MARK: - プロジェクト読み込み
    
    /// プロジェクトを読み込み
    func loadProject(withId id: UUID, completion: @escaping (LogoProject?) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // プロジェクトURLを取得
            let projectURL = self.url(for: id)
            
            do {
                // ファイルからJSONデータを読み込み
                let jsonData = try Data(contentsOf: projectURL)
                
                // JSONデータをプロジェクトオブジェクトに変換
                let project = try self.decoder.decode(LogoProject.self, from: jsonData)
                
                DispatchQueue.main.async { completion(project) }
            } catch {
                print("Failed to load project: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    /// プロジェクトを非同期で読み込み（Promise風）
    func loadProject(withId id: UUID) async throws -> LogoProject {
        return try await withCheckedThrowingContinuation { continuation in
            loadProject(withId: id) { project in
                if let project = project {
                    continuation.resume(returning: project)
                } else {
                    continuation.resume(throwing: ProjectStorageError.loadFailed)
                }
            }
        }
    }
    
    // MARK: - プロジェクト一覧
    
    /// 保存されているプロジェクト一覧を取得
    func getProjects(completion: @escaping ([LogoProject]) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            var projects: [LogoProject] = []
            
            do {
                // プロジェクトディレクトリ内のファイル一覧を取得
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: self.projectDirectoryURL,
                    includingPropertiesForKeys: nil
                )
                
                // 各ファイルからプロジェクトを読み込み
                for fileURL in fileURLs where fileURL.pathExtension == "json" {
                    if let project = try? self.loadProjectFromURL(fileURL) {
                        projects.append(project)
                    }
                }
                
                // 更新日時の新しい順にソート
                projects.sort { $0.updatedAt > $1.updatedAt }
                
                DispatchQueue.main.async { completion(projects) }
            } catch {
                print("Failed to get projects: \(error)")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }
    
    /// プロジェクトを非同期で一覧取得（Promise風）
    func getProjects() async -> [LogoProject] {
        return await withCheckedContinuation { continuation in
            getProjects { projects in
                continuation.resume(returning: projects)
            }
        }
    }
    
    // MARK: - プロジェクト削除
    
    /// プロジェクトを削除
    func deleteProject(withId id: UUID, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let projectURL = self.url(for: id)
            
            do {
                // ファイルが存在するか確認
                if FileManager.default.fileExists(atPath: projectURL.path) {
                    // ファイルを削除
                    try FileManager.default.removeItem(at: projectURL)
                    DispatchQueue.main.async { completion(true) }
                } else {
                    DispatchQueue.main.async { completion(false) }
                }
            } catch {
                print("Failed to delete project: \(error)")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    /// プロジェクトを非同期で削除（Promise風）
    func deleteProject(withId id: UUID) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            deleteProject(withId: id) { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ProjectStorageError.projectNotFound)
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
            print("Failed to save image asset: \(error)")
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
            print("Failed to delete image asset: \(error)")
            return false
        }
    }
    
    // MARK: - ヘルパーメソッド
    
    /// プロジェクトIDからファイルURLを取得
    private func url(for projectId: UUID) -> URL {
        return projectDirectoryURL.appendingPathComponent("\(projectId.uuidString).json")
    }
    
    /// URLからプロジェクトを読み込み
    private func loadProjectFromURL(_ url: URL) throws -> LogoProject {
        let jsonData = try Data(contentsOf: url)
        return try decoder.decode(LogoProject.self, from: jsonData)
    }
}
