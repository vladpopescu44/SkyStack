import Foundation

/// How the player drops a block during a build.
enum ControlScheme: String, CaseIterable, Identifiable, Codable, Sendable {
    /// A tap anywhere on the playfield drops the block.
    case tap
    /// A large button at the bottom drops the block.
    case button

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tap: "Tap anywhere"
        case .button: "Drop button"
        }
    }

    var systemImage: String {
        switch self {
        case .tap: "hand.tap.fill"
        case .button: "arrow.down.circle.fill"
        }
    }
}
