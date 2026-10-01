import SwiftUI
import UIKit

// MARK: - Palette
//
// The same Ink as Lift and Settle: one ink, one surface, a few greys, and
// nothing coloured. Light and dark are true inversions of each other. A
// box's state is carried by shape instead of colour: dashed while it's the
// wrong size, solid and shaded when it fits, solid ink when the board is done.

nonisolated private func dynamic(light: Double, dark: Double) -> Color {
    Color(UIColor { trait in
        UIColor(white: trait.userInterfaceStyle == .dark ? dark : light, alpha: 1)
    })
}

enum Ink {
    /// Paper-white in light, near-black in dark.
    static let canvas = dynamic(light: 1.00, dark: 0.04)
    static let surface = dynamic(light: 0.96, dark: 0.09)
    static let surfaceHigh = dynamic(light: 0.92, dark: 0.17)
    static let primary = dynamic(light: 0.05, dark: 0.98)
    static let secondary = dynamic(light: 0.40, dark: 0.66)
    static let tertiary = dynamic(light: 0.55, dark: 0.48)
    static let line = dynamic(light: 0.87, dark: 0.24)
    static let accent = dynamic(light: 0.05, dark: 0.98)
    static let onAccent = dynamic(light: 1.00, dark: 0.04)
}

extension View {
    /// Tiny wide-tracked uppercase caption, as in Lift and Settle.
    func microLabelStyle(_ color: Color = Ink.tertiary) -> some View {
        self.font(.system(size: 11, weight: .semibold))
            .tracking(1.1)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

enum Motion {
    static let snap = Animation.spring(response: 0.28, dampingFraction: 0.86)
}

// MARK: - Words

enum Copy {
    /// The line under the board. `dragging` is the box under the finger in
    /// the app; `byDragging` says how boxes are drawn where this is shown.
    static func status(
        _ board: Board,
        puzzle: Puzzle,
        showsTime: Bool,
        showsFit: Bool,
        dragging: Box? = nil,
        byDragging: Bool = false
    ) -> String {
        if let solved = board.solvedAt {
            if showsTime, let started = board.startedAt {
                let minutes = max(1, Int((solved.timeIntervalSince(started) / 60).rounded()))
                return "Solved in \(minutes) min"
            }
            return "Solved"
        }
        if let box = dragging { return "\(box.width) × \(box.height) = \(box.area)" }
        if board.anchor != nil { return "Now tap the opposite corner" }
        if board.boxes.isEmpty {
            return byDragging ? "Drag across the cells to draw a box" : "Tap two corners to draw a box"
        }
        // Counting boxes that fit would be a hint, so with hints off this
        // counts boxes drawn instead.
        if showsFit { return "\(board.satisfiedCount(in: puzzle)) of \(puzzle.clues.count) boxes fit" }
        return "\(board.boxes.count) of \(puzzle.clues.count) boxes drawn"
    }

    /// "Hard · 7×7"
    static func level(_ difficulty: Difficulty) -> String {
        "\(difficulty.title) · \(difficulty.size)×\(difficulty.size)"
    }

    static func date(_ day: Int) -> String {
        Generator.date(for: day).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

// MARK: - Appearance

extension View {
    /// Forces light or dark when the person has picked one; Automatic
    /// leaves the system's choice alone.
    @ViewBuilder
    func appearance(_ appearance: Appearance) -> some View {
        if let scheme = appearance.colorScheme {
            environment(\.colorScheme, scheme)
        } else {
            self
        }
    }
}
