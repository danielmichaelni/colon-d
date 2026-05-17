import Foundation

@MainActor
final class ReplacementOperationTracker {
    private var pendingID: UUID?

    var isPending: Bool {
        pendingID != nil
    }

    func begin() -> UUID {
        let id = UUID()
        pendingID = id
        return id
    }

    func complete(id: UUID) -> Bool {
        guard pendingID == id else { return false }
        pendingID = nil
        return true
    }

    func cancel() {
        pendingID = nil
    }
}
