//
//  ProjectStorageAsyncConcurrencyIntegrationTests.swift
//  GLogoTests
//
//  概要:
//  ProjectStorage の async API が Swift 6 移行後も
//  並行保存/読込/削除で整合性を保てることを検証する。
//

import XCTest
import CoreGraphics
@testable import GLogo

/// ProjectStorage の async I/O 整合性検証
final class ProjectStorageAsyncConcurrencyIntegrationTests: XCTestCase {
    /// 非同期保存・非同期読込の往復で内容が保持されることを確認
    /// - Parameters: なし
    /// - Returns: なし
    func testSaveAndLoadProjectAsync_RoundTrip() async throws {
        let storage = ProjectStorage.shared
        let project = makeProject(index: 1)

        do {
            try await storage.saveProject(project)
            let loaded = try await storage.loadProject(withId: project.id)

            XCTAssertEqual(loaded.id, project.id)
            XCTAssertEqual(loaded.name, project.name)
            XCTAssertEqual(loaded.canvasSize.width, project.canvasSize.width, accuracy: 0.0001)
            XCTAssertEqual(loaded.canvasSize.height, project.canvasSize.height, accuracy: 0.0001)
        } catch {
            try? await storage.deleteProject(withId: project.id)
            throw error
        }

        try? await storage.deleteProject(withId: project.id)
    }

    /// 複数プロジェクトの並行保存/並行読込が成立することを確認
    /// - Parameters: なし
    /// - Returns: なし
    func testSaveProjectAsync_ConcurrentRoundTripForMultipleProjects() async throws {
        let storage = ProjectStorage.shared
        let descriptors = (0..<6).map { index in
            let project = makeProject(index: index)
            return (
                id: project.id,
                name: project.name,
                width: project.canvasSize.width,
                height: project.canvasSize.height
            )
        }
        let ids = descriptors.map(\.id)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for descriptor in descriptors {
                    group.addTask {
                        let project = LogoProject(
                            name: descriptor.name,
                            canvasSize: CGSize(width: descriptor.width, height: descriptor.height)
                        )
                        project.id = descriptor.id
                        try await storage.saveProject(project)
                    }
                }
                try await group.waitForAll()
            }

            let loadedPairs = try await withThrowingTaskGroup(of: (UUID, (String, CGFloat, CGFloat)).self) { group in
                for id in ids {
                    group.addTask {
                        let project = try await storage.loadProject(withId: id)
                        return (id, (project.name, project.canvasSize.width, project.canvasSize.height))
                    }
                }

                var pairs: [(UUID, (String, CGFloat, CGFloat))] = []
                for try await pair in group {
                    pairs.append(pair)
                }
                return pairs
            }

            let loadedMap = Dictionary(uniqueKeysWithValues: loadedPairs)
            XCTAssertEqual(loadedMap.count, descriptors.count)

            for descriptor in descriptors {
                let loaded = try XCTUnwrap(loadedMap[descriptor.id])
                XCTAssertEqual(loaded.0, descriptor.name)
                XCTAssertEqual(loaded.1, descriptor.width, accuracy: 0.0001)
                XCTAssertEqual(loaded.2, descriptor.height, accuracy: 0.0001)
            }
        } catch {
            for id in ids {
                try? await storage.deleteProject(withId: id)
            }
            throw error
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for id in ids {
                group.addTask {
                    try? await storage.deleteProject(withId: id)
                }
            }
            try await group.waitForAll()
        }
    }

    // MARK: - Helpers

    /// 一意なテスト用プロジェクトを作成
    /// - Parameters:
    ///   - index: プロジェクト番号
    /// - Returns: テスト用 `LogoProject`
    private func makeProject(index: Int) -> LogoProject {
        let seed = UUID().uuidString
        return LogoProject(
            name: "ProjectStorageAsync_\(index)_\(seed)",
            canvasSize: CGSize(width: 1920 + CGFloat(index), height: 1080 + CGFloat(index))
        )
    }
}
