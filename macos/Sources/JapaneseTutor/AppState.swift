import Foundation

/// The conversation state machine, reflected in the menu-bar icon.
enum AppState: Equatable {
    case idle
    case listening
    case thinking
    case speaking
    case error(String)

    /// SF Symbol shown in the menu bar for this state.
    var symbolName: String {
        switch self {
        case .idle:      return "bubble.left.and.bubble.right"
        case .listening: return "waveform"
        case .thinking:  return "ellipsis.bubble"
        case .speaking:  return "speaker.wave.2.fill"
        case .error:     return "exclamationmark.triangle"
        }
    }
}
