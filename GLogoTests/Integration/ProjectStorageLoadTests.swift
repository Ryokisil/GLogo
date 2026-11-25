// ProjectStorage の読み込み4経路（単体・一覧の completion 版と async 版）が、渡した依存を画像要素へ届けることを、
// 実際のファイルへの保存と読み込みで検証する。引数を必須にしても、内部での渡し忘れは型では検出できないため。

import XCTest
@testable import GLogo

final class ProjectStorageLoadTests: XCTestCase {
    func test_loadAsync_passesDependencies() async throws {
        let id = try await saveImageProject()
        let fixed = FixedDecodingDependencies(color: .red)

        let project = try await ProjectStorage.shared.loadProject(withId: id, dependencies: fixed.dependencies)

        let image = try XCTUnwrap(project.elements.first as? ImageElement)
        XCTAssertTrue(fixed.isUsed(by: image))
    }

    func test_loadCompletion_passesDependencies() async throws {
        let id = try await saveImageProject()
        let fixed = FixedDecodingDependencies(color: .red)
        let loaded = expectation(description: "読み込みの完了")

        ProjectStorage.shared.loadProject(withId: id, dependencies: fixed.dependencies) { project in
            let image = project?.elements.first as? ImageElement
            XCTAssertNotNil(image, "保存した画像入りのプロジェクトを読み込める")
            XCTAssertTrue(image.map { fixed.isUsed(by: $0) } ?? false)
            loaded.fulfill()
        }
        await fulfillment(of: [loaded], timeout: 5)
    }

    func test_listAsync_includesImageProject() async throws {
        let id = try await saveImageProject()
        let fixed = FixedDecodingDependencies(color: .red)

        let projects = await ProjectStorage.shared.getProjects(dependencies: fixed.dependencies)

        // 一覧は読み込めないファイルを黙って飛ばすため、保存した画像入りのプロジェクトが含まれることまで確かめる。
        let project = try XCTUnwrap(projects.first { $0.id == id })
        let image = try XCTUnwrap(project.elements.first as? ImageElement)
        XCTAssertTrue(fixed.isUsed(by: image))
    }

    func test_listCompletion_includesImageProject() async throws {
        let id = try await saveImageProject()
        let fixed = FixedDecodingDependencies(color: .red)
        let listed = expectation(description: "一覧の完了")

        ProjectStorage.shared.getProjects(dependencies: fixed.dependencies) { projects in
            let image = projects.first { $0.id == id }?.elements.first as? ImageElement
            XCTAssertNotNil(image, "読み込めないファイルとして飛ばされず、一覧に含まれる")
            XCTAssertTrue(image.map { fixed.isUsed(by: $0) } ?? false)
            listed.fulfill()
        }
        await fulfillment(of: [listed], timeout: 5)
    }

    func test_concurrentLoads_keepDependenciesSeparate() async throws {
        let id = try await saveImageProject()
        let red = FixedDecodingDependencies(color: .red)
        let blue = FixedDecodingDependencies(color: .blue)

        // 同じプロジェクトを別々の依存で並行に読み込み、それぞれの画像要素へ自分の依存だけが届くことを確かめる。
        // 偽物は不変の値だけを持つため、並行に触っても観測値が壊れない。
        let results = try await withThrowingTaskGroup(of: (own: Bool, other: Bool).self) { group in
            for (own, other) in [(red, blue), (blue, red)] {
                group.addTask {
                    let project = try await ProjectStorage.shared.loadProject(withId: id, dependencies: own.dependencies)
                    let image = try XCTUnwrap(project.elements.first as? ImageElement)
                    return (own.isUsed(by: image), other.isUsed(by: image))
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }

        XCTAssertEqual(results.count, 2)
        for result in results {
            XCTAssertTrue(result.own, "読み込みに渡した依存が届く")
            XCTAssertFalse(result.other, "並行する別の読み込みの依存は混ざらない")
        }
    }

    // MARK: - Helpers

    /// 画像要素を1つ含むプロジェクトを保存し、テストの終わりに削除する
    private func saveImageProject() async throws -> UUID {
        let project = LogoProject(
            name: "ProjectStorageLoad_\(UUID().uuidString)",
            canvasSize: CGSize(width: 640, height: 480)
        )
        let imageData = try XCTUnwrap(snapshotImage(.green).pngData())
        project.addElement(ImageElementFactory().makeElement(imageData: imageData))
        let id = project.id
        addTeardownBlock {
            try? await ProjectStorage.shared.deleteProject(withId: id)
        }
        try await ProjectStorage.shared.saveProject(project)
        return id
    }
}
