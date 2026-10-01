import Foundation

// MARK: - Geometry

/// A rectangle of cells on the board, inclusive at both ends.
nonisolated struct Box: Codable, Hashable, Sendable {
    var top: Int
    var left: Int
    var bottom: Int
    var right: Int

    init(top: Int, left: Int, bottom: Int, right: Int) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    /// The smallest box containing both cells, whichever corner each one is.
    init(spanning a: Int, _ b: Int, size: Int) {
        let (ar, ac) = (a / size, a % size)
        let (br, bc) = (b / size, b % size)
        self.init(top: min(ar, br), left: min(ac, bc), bottom: max(ar, br), right: max(ac, bc))
    }

    var width: Int { right - left + 1 }
    var height: Int { bottom - top + 1 }
    var area: Int { width * height }

    func contains(_ cell: Int, size: Int) -> Bool {
        let r = cell / size, c = cell % size
        return r >= top && r <= bottom && c >= left && c <= right
    }

    func overlaps(_ other: Box) -> Bool {
        top <= other.bottom && other.top <= bottom && left <= other.right && other.left <= right
    }

    /// One bit per cell. Boards are at most 8×8, so 64 bits is enough.
    func mask(size: Int) -> UInt64 {
        var m: UInt64 = 0
        for r in top...bottom {
            for c in left...right { m |= 1 << UInt64(r * size + c) }
        }
        return m
    }
}

// MARK: - Puzzle

nonisolated enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard

    var title: String { rawValue.capitalized }

    /// Board edge in cells. Bigger boards are harder, and 7×7 is the most a
    /// large widget can hold while keeping every cell a comfortable tap.
    var size: Int {
        switch self {
        case .easy: 5
        case .medium: 6
        case .hard: 7
        }
    }
}

nonisolated struct Clue: Codable, Hashable, Sendable {
    let cell: Int
    let value: Int
}

nonisolated struct Puzzle: Codable, Hashable, Sendable {
    /// Days since the reference date; the puzzle's identity.
    let day: Int
    let difficulty: Difficulty
    let size: Int
    /// Sorted by cell.
    let clues: [Clue]
    /// The one solution, kept for tests and a future "reveal".
    let solution: [Box]

    var cellCount: Int { size * size }

    func clue(at cell: Int) -> Clue? {
        clues.first { $0.cell == cell }
    }

    /// The clues inside a box.
    func clues(in box: Box) -> [Clue] {
        clues.filter { box.contains($0.cell, size: size) }
    }

    /// A placed box is right when it holds exactly one number and that number
    /// is its area. That's local: it can be right and still not be the answer.
    func isSatisfied(_ box: Box) -> Bool {
        let inside = clues(in: box)
        return inside.count == 1 && inside[0].value == box.area
    }

    /// Solved when the boxes tile the board and each one is satisfied. Any
    /// such tiling counts, though generated puzzles only have one.
    func isSolved(by boxes: [Box]) -> Bool {
        guard boxes.count == clues.count else { return false }
        var covered: UInt64 = 0
        for box in boxes {
            guard isSatisfied(box) else { return false }
            let m = box.mask(size: size)
            if covered & m != 0 { return false }
            covered |= m
        }
        return covered.nonzeroBitCount == cellCount
    }
}
