import AppKit

extension Notification.Name { static let preferencesChanged = Notification.Name("BudNotePreferencesChanged") }
final class Preferences {
    static let shared = Preferences()
    private let defaults: UserDefaults
    private init() {
        #if DEBUG
        if let suite = ProcessInfo.processInfo.environment["BUDNOTE_TEST_DEFAULTS_SUITE"] {
            defaults = UserDefaults(suiteName: suite)!
        } else { defaults = .standard }
        #else
        defaults = .standard
        #endif
        defaults.register(defaults: ["fontSize": 15.0, "wrap": true, "lineNumbers": true, "theme": 0, "language": 0]) }
    var fontSize: Double { get { defaults.double(forKey: "fontSize") } set { defaults.set(min(40, max(10, newValue)), forKey: "fontSize"); notify() } }
    var wrap: Bool { get { defaults.bool(forKey: "wrap") } set { defaults.set(newValue, forKey: "wrap"); notify() } }
    var lineNumbers: Bool { get { defaults.bool(forKey: "lineNumbers") } set { defaults.set(newValue, forKey: "lineNumbers"); notify() } }
    var theme: Int { get { defaults.integer(forKey: "theme") } set { defaults.set(newValue, forKey: "theme"); notify() } }
    var language: Int { get { defaults.integer(forKey: "language") } set { defaults.set(newValue, forKey: "language"); notify() } }
    var isEnglish: Bool { language == 1 }
    func applyAppearance() {
        let appearance = theme == 1 ? NSAppearance(named: .aqua) : theme == 2 ? NSAppearance(named: .darkAqua) : nil
        NSApp.appearance = appearance
        // Explicitly reset every window as well, including settings and About.
        for window in NSApp.windows { window.appearance = appearance }
    }
    private func notify() { applyAppearance(); NotificationCenter.default.post(name: .preferencesChanged, object: nil) }
}
func tr(_ zh: String, _ en: String) -> String { Preferences.shared.isEnglish ? en : zh }
enum Palette {
    static let background = NSColor(name: "MeadowBackground") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.114, green: 0.145, blue: 0.129, alpha: 1)
            : NSColor(srgbRed: 0.984, green: 0.992, blue: 0.977, alpha: 1)
    }
    static let accent = NSColor(name: "MeadowAccent") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.63, green: 0.83, blue: 0.67, alpha: 1)
            : NSColor(srgbRed: 0.22, green: 0.46, blue: 0.34, alpha: 1)
    }
}
