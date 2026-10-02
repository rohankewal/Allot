import Foundation

/// Someone's progress on one day's puzzle.
nonisolated struct Board: Codable, Hashable, Sendable {
    let day: Int
    /// Changing difficulty in Settings swaps the puzzle, so a board belongs
    /// to one day at one level.
    let difficulty: Difficulty
    var boxes: [Box] = []
    /// The first corner of a box being drawn.
    var anchor: Int?
    var startedAt: Date?
    var solvedAt: Date?

    init(for puzzle: Puzzle) {
        day = puzzle.day
        difficulty = puzzle.difficulty
    }

    func belongs(to puzzle: Puzzle) -> Bool {
        day == puzzle.day && difficulty == puzzle.difficulty
    }

    var isSolved: Bool { solvedAt != nil }
    var isEmpty: Bool { boxes.isEmpty && anchor == nil }

    /// Puts a box down. A new box replaces any it overlaps.
    mutating func place(_ box: Box, puzzle: Puzzle, now: Date = .now) {
        guard !isSolved else { return }
        if startedAt == nil { startedAt = now }
        boxes.removeAll { $0.overlaps(box) }
        boxes.append(box)
        anchor = nil
        if puzzle.isSolved(by: boxes) { solvedAt = now }
    }

    /// Drawing in two taps (widgets can't follow a drag): tap one corner, then the opposite one. Tapping the first
    /// corner again cancels it (boxes are at least two cells), and tapping a
    /// box when nothing is being drawn removes it.
    mutating func tap(_ cell: Int, puzzle: Puzzle, now: Date = .now) {
        guard !isSolved, cell >= 0, cell < puzzle.cellCount else { return }
        if let anchor {
            if anchor == cell {
                self.anchor = nil
            } else {
                place(Box(spanning: anchor, cell, size: puzzle.size), puzzle: puzzle, now: now)
            }
        } else if let index = boxes.firstIndex(where: { $0.contains(cell, size: puzzle.size) }) {
            boxes.remove(at: index)
        } else {
            anchor = cell
            if startedAt == nil { startedAt = now }
        }
    }

    mutating func clear() {
        guard !isSolved else { return }
        boxes = []
        anchor = nil
    }

    /// Boxes that hold one number matching their size.
    func satisfiedCount(in puzzle: Puzzle) -> Int {
        boxes.filter(puzzle.isSatisfied).count
    }
}
