import Foundation

/// What the plaza is made of. A theme dresses the same two layouts in a different
/// world — marble and olive trees, sand and palms, or a sunflower stop and rabbits —
/// and every surface of the app draws whichever one the user last picked.
public enum PlazaTheme: String, Codable, CaseIterable, Sendable {
    case agora
    case seaside
    case antonovka

    public var displayName: String {
        switch self {
        case .agora: return "Greek Agora"
        case .seaside: return "Sunny Seaside"
        case .antonovka: return "Antonovka Stop"
        }
    }

    /// Cats are drawn in profile and flip to face the way they are going.
    /// People and rabbits are drawn face-on.
    public var actorsTurnToWalk: Bool {
        self == .seaside
    }

    public static var current: PlazaTheme {
        get {
            let raw = UserDefaults.standard.string(forKey: AgoreConstants.themeKey) ?? ""
            return PlazaTheme(rawValue: raw) ?? .agora
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: AgoreConstants.themeKey)
        }
    }
}
