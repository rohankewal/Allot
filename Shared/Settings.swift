import Foundation
import SwiftUI
import UIKit

// Settings live in the App Group so the widget sees the same choices as the
// app. The app writes them through @AppStorage with `Settings.defaults` as
// the store; everything else reads them here.

nonisolated enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

nonisolated enum DifficultyChoice: String, CaseIterable, Identifiable, Sendable {
    /// Easy, medium or hard at random each day.
    case daily, easy, medium, hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily mix"
        case .easy: "Always easy"
        case .medium: "Always medium"
        case .hard: "Always hard"
        }
    }

    func resolve(day: Int) -> Difficulty {
        switch self {
        case .daily: Generator.difficulty(for: day)
        case .easy: .easy
        case .medium: .medium
        case .hard: .hard
        }
    }
}

nonisolated enum Settings {
    static let appGroup = "group.com.rohankewalramani.Allot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    enum Key {
        static let appearance = "appearance"
        static let difficulty = "difficulty"
        static let showsFit = "showsFit"
        static let showsTime = "showsTime"
        static let haptics = "haptics"
        static let reminderOn = "reminderOn"
        static let reminderMinutes = "reminderMinutes"
    }

    static var appearance: Appearance {
        defaults.string(forKey: Key.appearance).flatMap(Appearance.init) ?? .system
    }

    static var difficulty: DifficultyChoice {
        defaults.string(forKey: Key.difficulty).flatMap(DifficultyChoice.init) ?? .daily
    }

    /// Dashed outline on boxes that are the wrong size. Off for people who
    /// want no hints until the board is done.
    static var showsFit: Bool { bool(Key.showsFit, default: true) }
    static var showsTime: Bool { bool(Key.showsTime, default: true) }
    static var haptics: Bool { bool(Key.haptics, default: true) }
    static var reminderOn: Bool { bool(Key.reminderOn, default: false) }

    /// Minutes after midnight. 9:00 by default.
    static var reminderMinutes: Int {
        defaults.object(forKey: Key.reminderMinutes) as? Int ?? 9 * 60
    }

    private static func bool(_ key: String, default value: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? value
    }
}
