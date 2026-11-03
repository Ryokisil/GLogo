// UseCase がモデルを直接変更せず、イベントと対象IDを適用先へ渡すことを確認する。

import Foundation
@testable import GLogo

@MainActor
final class ElementEditTargetSpy: ImageEditCommitting {
    var images: [ImageElement] = []

    func imageEditToken(for element: ImageElement) -> ImageEditToken? {
        guard images.contains(where: { $0 === element }) else { return nil }
        return ImageEditToken(element: ObjectIdentifier(element), imageRevision: element.editRevision,
                              historyRestorationRevision: 0)
    }
    private(set) var imageRefreshes: [(UUID, Bool)] = []

    func applyImageEvents(_ events: [EditorEvent], elementId: UUID, selectsResult: Bool) {
        self.events.append(contentsOf: events)
        imageRefreshes.append((elementId, selectsResult))
    }

    private(set) var events: [EditorEvent] = []
    private(set) var refreshedIDs: [UUID] = []
    private(set) var previews: [LogoElement] = []

    func updateSelectedElement(_ element: LogoElement) {
        previews.append(element)
    }

    func applyEventAndRefreshSelection(_ event: EditorEvent, elementId: UUID) {
        events.append(event)
        refreshedIDs.append(elementId)
    }

    func applyEvent(_ event: EditorEvent) {
        events.append(event)
    }
}
