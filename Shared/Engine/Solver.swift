import Foundation

/// Solves boards the way a person would, so the generator can tell how hard
/// a board is as well as whether it has exactly one answer.
nonisolated enum Solver {

    /// The hardest kind of reasoning a board needed.
    enum Technique: Int, Comparable, Sendable {
        /// Only one rectangle fits a number, or only one number can reach a cell.
        case basic
        /// Cells every option for a number shares are spoken for, which
        /// rules out other numbers' options there.
        case overlap
        /// Logic runs out and you have to try something and see.
        case guess

        static func < (a: Technique, b: Technique) -> Bool { a.rawValue < b.rawValue }
    }

    struct Report: Sendable {
        /// 0, 1, or 2 meaning "more than one".
        let solutions: Int
        let technique: Technique
        /// Times the logical solver reached for its overlap rule.
        let overlapSteps: Int
    }

    /// Every rectangle each clue could be: the right area, covering the clue,
    /// on the board, and holding no other number.
    static func options(for puzzle: Puzzle) -> [[UInt64]] {
        let n = puzzle.size
        var clueMask: UInt64 = 0
        for clue in puzzle.clues { clueMask |= 1 << UInt64(clue.cell) }

        return puzzle.clues.map { clue in
            let r = clue.cell / n, c = clue.cell % n
            let own: UInt64 = 1 << UInt64(clue.cell)
            var result: [UInt64] = []
            for h in 1...min(n, clue.value) where clue.value % h == 0 {
                let w = clue.value / h
                guard w <= n else { continue }
                for top in max(0, r - h + 1)...r where top + h <= n {
                    for left in max(0, c - w + 1)...c where left + w <= n {
                        let m = Box(top: top, left: left, bottom: top + h - 1, right: left + w - 1).mask(size: n)
                        if m & clueMask & ~own == 0 { result.append(m) }
                    }
                }
            }
            return result
        }
    }

    // MARK: Logic

    private struct State {
        var options: [[UInt64]]
        var placed: [Bool]
        var covered: UInt64 = 0
    }

    private enum Outcome { case solved, stuck, contradiction }

    /// Applies one round of the basic rules. Returns nil on contradiction,
    /// otherwise whether anything changed.
    private static func basicPass(_ s: inout State, cells: Int) -> Bool? {
        var changed = false
        // A number's options can't use cells already taken.
        for k in s.options.indices where !s.placed[k] {
            let before = s.options[k].count
            s.options[k].removeAll { $0 & s.covered != 0 }
            if s.options[k].isEmpty { return nil }
            if s.options[k].count != before { changed = true }
            if s.options[k].count == 1 {
                s.placed[k] = true
                s.covered |= s.options[k][0]
                changed = true
            }
        }
        // Every empty cell needs a number that can reach it; if only one can,
        // that number must.
        var cell = 0
        while cell < cells {
            let bit: UInt64 = 1 << UInt64(cell)
            if s.covered & bit == 0 {
                var owner = -1
                var owners = 0
                for k in s.options.indices where !s.placed[k] {
                    if s.options[k].contains(where: { $0 & bit != 0 }) {
                        owners += 1
                        owner = k
                        if owners > 1 { break }
                    }
                }
                if owners == 0 { return nil }
                if owners == 1 {
                    let before = s.options[owner].count
                    s.options[owner].removeAll { $0 & bit == 0 }
                    if s.options[owner].count != before { changed = true }
                }
            }
            cell += 1
        }
        return changed
    }

    /// The overlap rule. Returns nil on contradiction, otherwise whether it helped.
    private static func overlapPass(_ s: inout State) -> Bool? {
        var changed = false
        for k in s.options.indices where !s.placed[k] {
            let shared = s.options[k].reduce(~UInt64(0)) { $0 & $1 }
            guard shared != 0 else { continue }
            for j in s.options.indices where j != k && !s.placed[j] {
                let before = s.options[j].count
                s.options[j].removeAll { $0 & shared != 0 }
                if s.options[j].isEmpty { return nil }
                if s.options[j].count != before { changed = true }
            }
        }
        return changed
    }

    private static func deduce(_ s: inout State, cells: Int, useOverlap: Bool, overlapSteps: inout Int) -> Outcome {
        let full: UInt64 = cells == 64 ? ~0 : (1 << UInt64(cells)) - 1
        while true {
            guard let changed = basicPass(&s, cells: cells) else { return .contradiction }
            if s.covered == full && !s.placed.contains(false) { return .solved }
            if changed { continue }
            guard useOverlap else { return .stuck }
            guard let helped = overlapPass(&s) else { return .contradiction }
            if !helped { return .stuck }
            overlapSteps += 1
        }
    }

    // MARK: Public

    static func analyse(_ puzzle: Puzzle) -> Report {
        let opts = options(for: puzzle)
        let cells = puzzle.cellCount
        let start = State(options: opts, placed: Array(repeating: false, count: opts.count))

        // How far does logic alone get?
        var technique = Technique.basic
        var overlapSteps = 0
        var s = start
        var unused = 0
        switch deduce(&s, cells: cells, useOverlap: false, overlapSteps: &unused) {
        case .contradiction: return Report(solutions: 0, technique: .basic, overlapSteps: 0)
        case .solved: break
        case .stuck:
            s = start
            switch deduce(&s, cells: cells, useOverlap: true, overlapSteps: &overlapSteps) {
            case .contradiction: return Report(solutions: 0, technique: .overlap, overlapSteps: overlapSteps)
            case .solved: technique = .overlap
            case .stuck: technique = .guess
            }
        }

        let count = countSolutions(start, cells: cells, limit: 2)
        return Report(solutions: count, technique: technique, overlapSteps: overlapSteps)
    }

    /// Depth-first search with logic at every node, stopping at `limit`.
    private static func countSolutions(_ state: State, cells: Int, limit: Int) -> Int {
        var s = state
        var steps = 0
        switch deduce(&s, cells: cells, useOverlap: true, overlapSteps: &steps) {
        case .contradiction: return 0
        case .solved: return 1
        case .stuck: break
        }
        // Branch on the number with the fewest options left.
        var best = -1
        for k in s.options.indices where !s.placed[k] {
            if best < 0 || s.options[k].count < s.options[best].count { best = k }
        }
        guard best >= 0 else { return 0 }
        var total = 0
        for option in s.options[best] {
            var next = s
            next.options[best] = [option]
            next.placed[best] = true
            next.covered |= option
            total += countSolutions(next, cells: cells, limit: limit - total)
            if total >= limit { return total }
        }
        return total
    }
}
