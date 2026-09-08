import SwiftUI
import Observation

enum RCColorway: String, Codable, CaseIterable, Identifiable {
    case play, poolside, punch

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var subtitle: String {
        switch self {
        case .play: return "Violet kicks. Butter-yellow smiles."
        case .poolside: return "Fresh teal with a peachy little twist."
        case .punch: return "Pink fizz. A bold splash of blue."
        }
    }
    var colorScheme: ColorScheme { .light }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        // Keep existing appearance preferences usable across the Pep rebrand.
        switch value {
        case "play", "daybreak": self = .play
        case "poolside", "tidal": self = .poolside
        case "punch", "afterglow": self = .punch
        default: self = .play
        }
    }

    var palette: RCPalette {
        switch self {
        case .play:
            return RCPalette(background: 0xF7F5FC, card: 0xFFFFFF, border: 0xE6E0F0,
                             text: 0x282239, muted: 0x746C83, accent: 0x6547D5,
                             accentText: 0x5B3CBF, secondary: 0x23796D, onAccent: 0xFFFFFF,
                             heroStart: 0xE5DEFC, heroEnd: 0xFFE9A1,
                             orbHighlight: 0xFFD85F, orbMid: 0xF5B594, orbShadow: 0x6547D5)
        case .poolside:
            return RCPalette(background: 0xF1F8F5, card: 0xFFFFFF, border: 0xDCEAE4,
                             text: 0x193F3D, muted: 0x5D7772, accent: 0x177A6D,
                             accentText: 0x146C61, secondary: 0xA24C32, onAccent: 0xFFFFFF,
                             heroStart: 0xD1EEE3, heroEnd: 0xFFDCC0,
                             orbHighlight: 0xFFBA92, orbMid: 0xF69573, orbShadow: 0x177A6D)
        case .punch:
            return RCPalette(background: 0xFFF5F8, card: 0xFFFFFF, border: 0xF1DFE7,
                             text: 0x39273E, muted: 0x806579, accent: 0xB93678,
                             accentText: 0xA72E6A, secondary: 0x3D5BD1, onAccent: 0xFFFFFF,
                             heroStart: 0xFBD8E9, heroEnd: 0xDBE2FF,
                             orbHighlight: 0xFFCE72, orbMid: 0xF9A0B9, orbShadow: 0x3D5BD1)
        }
    }
}

struct RCPalette {
    let background: UInt32
    let card: UInt32
    let border: UInt32
    let text: UInt32
    let muted: UInt32
    let accent: UInt32
    let accentText: UInt32
    let secondary: UInt32
    let onAccent: UInt32
    let heroStart: UInt32
    let heroEnd: UInt32
    let orbHighlight: UInt32
    let orbMid: UInt32
    let orbShadow: UInt32
}

@Observable
final class RCAppearance {
    #if DEBUG
    static let shared = RCAppearance(fileURL: PepUITestLaunch.appearanceFileURL)
    #else
    static let shared = RCAppearance()
    #endif

    var selected: RCColorway { didSet { persist() } }
    var motionEnabled: Bool { didSet { persist() } }
    private(set) var saveError: String?
    @ObservationIgnored private let fileURL: URL

    var colorScheme: ColorScheme { selected.colorScheme }

    init(fileURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = fileURL ?? support.appendingPathComponent("RepComet/appearance.json")
        let stored = (try? Data(contentsOf: self.fileURL)).flatMap { try? JSONDecoder().decode(Preferences.self, from: $0) }
        selected = stored?.selected ?? .play
        motionEnabled = stored?.motionEnabled ?? true
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Preferences(selected: selected, motionEnabled: motionEnabled))
            try data.write(to: fileURL, options: .atomic)
            saveError = nil
        } catch {
            saveError = "Your look changed, but couldn't be saved for next time."
        }
    }

    private struct Preferences: Codable {
        let selected: RCColorway
        let motionEnabled: Bool
    }
}
