import Foundation
import Observation

/// Handles unlocking and selecting builders.
@MainActor
@Observable
final class BuildersViewModel {
    enum Status: Equatable {
        case equipped
        case unlocked
        case locked(price: Int)
    }

    let store: ProfileStore
    private let haptics: HapticsService

    var toastMessage: String?
    var toastIsError = false
    private(set) var shakeCounts: [BuilderSkin: Int] = [:]

    init(store: ProfileStore, haptics: HapticsService) {
        self.store = store
        self.haptics = haptics
    }

    var stars: Int { store.profile.stars }
    var selected: BuilderSkin { store.profile.selectedBuilder }

    func status(of skin: BuilderSkin) -> Status {
        if store.profile.selectedBuilder == skin { return .equipped }
        if store.profile.isUnlocked(skin) { return .unlocked }
        return .locked(price: skin.price)
    }

    func canUnlock(_ skin: BuilderSkin) -> Bool {
        store.canAfford(skin.price)
    }

    /// Selects an unlocked builder or unlocks a locked one.
    func activate(_ skin: BuilderSkin) {
        do {
            switch status(of: skin) {
            case .equipped:
                return
            case .unlocked:
                try store.selectBuilder(skin)
                haptics.selection()
                show("\(skin.title) is ready to build.", isError: false)
            case .locked:
                try store.unlockBuilder(skin)
                haptics.notify(.success)
                show("\(skin.title) unlocked and equipped.", isError: false)
            }
        } catch {
            shakeCounts[skin, default: 0] += 1
            haptics.notify(.error)
            show(error.localizedDescription, isError: true)
        }
    }

    private func show(_ message: String, isError: Bool) {
        toastIsError = isError
        toastMessage = message
    }
}
