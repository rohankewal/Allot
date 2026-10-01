import SwiftUI

// MARK: - Palette
//
// The same Ink as Lift and Settle, light side only: one ink on white paper
// and a few greys. Nothing is coloured. A box's state is carried by shape
// instead: dashed while it's the wrong size, solid and shaded when it fits,
// solid ink when the whole board is done.

enum Ink {
    static let canvas = Color(white: 1.00)
    static let surface = Color(white: 0.96)
    static let surfaceHigh = Color(white: 0.92)
    static let primary = Color(white: 0.05)
    static let secondary = Color(white: 0.40)
    static let tertiary = Color(white: 0.55)
    static let line = Color(white: 0.87)
    static let accent = Color(white: 0.05)
    static let onAccent = Color(white: 1.00)
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
    static func status(_ board: Board, puzzle: Puzzle) -> String {
        if let solved = board.solvedAt {
            if let started = board.startedAt {
                let minutes = max(1, Int((solved.timeIntervalSince(started) / 60).rounded()))
                return "Solved in \(minutes) min"
            }
            return "Solved"
        }
        if board.anchor != nil { return "Now tap the opposite corner" }
        if board.boxes.isEmpty { return "Tap two corners to draw a box" }
        return "\(board.satisfiedCount(in: puzzle)) of \(puzzle.clues.count) boxes"
    }

    static func date(_ day: Int) -> String {
        Generator.date(for: day).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
