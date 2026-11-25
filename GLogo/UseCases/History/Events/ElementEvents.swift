// 要素の追加・削除・回転・変形（移動・リサイズ・回転の組み合わせ）を記録する履歴イベント。

import Foundation

/// 要素追加イベント
struct ElementAddedEvent: EditorEvent {
    let element: LogoElement

    var description: String {
        return "\(element.name)を追加しました"
    }

    func apply(to project: LogoProject) {
        project.elements.append(element)
    }

    func revert(from project: LogoProject) {
        project.elements.removeAll { $0.id == element.id }
    }
}

/// 要素削除イベント
struct ElementRemovedEvent: EditorEvent {
    let element: LogoElement
    let index: Int

    var description: String {
        return "\(element.name)を削除しました"
    }

    func apply(to project: LogoProject) {
        project.elements.removeAll { $0.id == element.id }
    }

    func revert(from project: LogoProject) {
        // インデックスが範囲内かチェック
        let safeIndex = min(index, project.elements.count)
        project.elements.insert(element, at: safeIndex)
    }
}

/// 要素回転イベント
struct ElementRotatedEvent: EditorEvent {
    let elementId: UUID
    let oldRotation: CGFloat
    let newRotation: CGFloat

    var description: String {
        return "要素を回転しました"
    }

    func apply(to project: LogoProject) {
        if let element = project.element(for: elementId) {
            element.rotation = newRotation
        }
    }

    func revert(from project: LogoProject) {
        if let element = project.element(for: elementId) {
            element.rotation = oldRotation
        }
    }
}

/// 要素の複合変更イベント（移動 + サイズ変更 + 回転）
struct ElementTransformedEvent: EditorEvent {
    let elementId: UUID
    let oldPosition: CGPoint?
    let newPosition: CGPoint?
    let oldSize: CGSize?
    let newSize: CGSize?
    let oldRotation: CGFloat?
    let newRotation: CGFloat?

    var description: String {
        var desc = "要素を"
        if oldPosition != nil { desc += "移動" }
        if oldSize != nil { desc += oldPosition != nil ? "・リサイズ" : "リサイズ" }
        if oldRotation != nil { desc += (oldPosition != nil || oldSize != nil) ? "・回転" : "回転" }
        desc += "しました"
        return desc
    }

    func apply(to project: LogoProject) {
        guard let element = project.element(for: elementId) else { return }

        if let newPosition = newPosition {
            element.position = newPosition
        }

        if let newSize = newSize {
            element.size = newSize
        }

        if let newRotation = newRotation {
            element.rotation = newRotation
        }
    }

    func revert(from project: LogoProject) {
        guard let element = project.element(for: elementId) else { return }

        if let oldPosition = oldPosition {
            element.position = oldPosition
        }

        if let oldSize = oldSize {
            element.size = oldSize
        }

        if let oldRotation = oldRotation {
            element.rotation = oldRotation
        }
    }
}
