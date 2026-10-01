import Foundation

/// Makes the day's puzzle. Everything is seeded by the date, so every phone
/// makes the same board for the same day without a server, and the board
/// changes at midnight whether or not yesterday's was finished.
nonisolated enum Generator {

    /// What each difficulty asks of a board.
    struct Profile: Sendable {
        let size: Int
        /// Relative chance of each area (index = area). Area 1 is always 0:
        /// there are no single-cell boxes, so the smallest number is 2.
        let areaWeights: [Int]
        /// The hardest reasoning allowed, and the easiest required.
        let minTechnique: Solver.Technique
        let maxTechnique: Solver.Technique
        /// For hard boards: how many times the overlap rule must be needed.
        let minOverlapSteps: Int
    }

    static func profile(_ difficulty: Difficulty) -> Profile {
        switch difficulty {
        case .easy:
            Profile(size: 5,
                    areaWeights: [0, 0, 10, 14, 12, 8, 6],
                    minTechnique: .basic, maxTechnique: .basic, minOverlapSteps: 0)
        case .medium:
            Profile(size: 6,
                    areaWeights: [0, 0, 6, 10, 12, 10, 9, 6, 6, 4],
                    minTechnique: .basic, maxTechnique: .overlap, minOverlapSteps: 0)
        case .hard:
            Profile(size: 7,
                    areaWeights: [0, 0, 3, 6, 9, 9, 10, 7, 8, 6, 5, 3, 4],
                    minTechnique: .overlap, maxTechnique: .overlap, minOverlapSteps: 2)
        }
    }

    // MARK: Daily

    /// 1 January 2026 is day 0.
    static func day(for date: Date, calendar: Calendar = .current) -> Int {
        let epoch = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: epoch), to: calendar.startOfDay(for: date)).day!
    }

    static func date(for day: Int, calendar: Calendar = .current) -> Date {
        let epoch = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        return calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: epoch))!
    }

    /// The difficulty is drawn at random each day, independent of the
    /// previous day, so you can't tell what's coming.
    static func difficulty(for day: Int) -> Difficulty {
        var rng = SeededRandom(seed: seed(day, salt: 0xD1FF))
        return Difficulty.allCases[rng.int(Difficulty.allCases.count)]
    }

    /// The day's board at a difficulty: the random one unless someone has
    /// picked a fixed level in Settings. Same day and level, same board, so
    /// everyone who plays Hard on a given day gets the same Hard board.
    static func puzzle(for day: Int, difficulty: Difficulty? = nil) -> Puzzle {
        let level = difficulty ?? self.difficulty(for: day)
        let key = "\(day)-\(level.rawValue)"
        if let cached = cache.withLock({ $0[key] }) { return cached }
        let made = make(day: day, difficulty: level)
        cache.withLock {
            if $0.count > 6 { $0.removeAll() }
            $0[key] = made
        }
        return made
    }

    private static let cache = Locked<[String: Puzzle]>([:])

    private static func seed(_ day: Int, salt: UInt64) -> UInt64 {
        UInt64(bitPattern: Int64(day)) &* 0x2545_F491_4F6C_DD1D ^ salt
    }

    // MARK: Making a board

    static func make(day: Int, difficulty: Difficulty) -> Puzzle {
        var rng = SeededRandom(seed: seed(day, salt: 0x5A1C_A4C0))
        let p = profile(difficulty)
        var fallback: Puzzle?

        for _ in 0..<4000 {
            guard let boxes = partition(size: p.size, weights: p.areaWeights, rng: &rng) else { continue }
            // Lots of 2s make a board feel filled in before you start.
            guard boxes.filter({ $0.area == 2 }).count * 4 <= boxes.count + 1 else { continue }
            // A few clue placements per tiling before giving it up.
            for _ in 0..<6 {
                let clues = boxes.map { box -> Clue in
                    let r = box.top + rng.int(box.height)
                    let c = box.left + rng.int(box.width)
                    return Clue(cell: r * p.size + c, value: box.area)
                }.sorted { $0.cell < $1.cell }
                let puzzle = Puzzle(day: day, difficulty: difficulty, size: p.size, clues: clues, solution: boxes)
                let report = Solver.analyse(puzzle)
                guard report.solutions == 1, report.technique != .guess else { continue }
                if fallback == nil { fallback = puzzle }
                if report.technique >= p.minTechnique, report.technique <= p.maxTechnique,
                   report.overlapSteps >= p.minOverlapSteps {
                    return puzzle
                }
            }
        }
        // Never reached in testing; a unique board is still a fair board.
        return fallback ?? make(day: day &+ 7919, difficulty: difficulty)
    }

    /// Tiles the board with random rectangles, filling cells in reading
    /// order: each empty cell becomes the top-left of a new rectangle.
    /// Nil when a cell gets boxed in with no allowed shape left (a lone
    /// corner cell, now that 1×1 isn't allowed); the caller tries again.
    static func partition(size n: Int, weights: [Int], rng: inout SeededRandom) -> [Box]? {
        var covered: UInt64 = 0
        var boxes: [Box] = []
        let maxArea = weights.count - 1

        for cell in 0..<(n * n) where covered & (1 << UInt64(cell)) == 0 {
            let r = cell / n, c = cell % n
            var shapes: [Box] = []
            var shapeWeights: [Int] = []
            for h in 1...(n - r) {
                for w in 1...(n - c) {
                    let area = w * h
                    guard area <= maxArea, weights[area] > 0 else { continue }
                    let box = Box(top: r, left: c, bottom: r + h - 1, right: c + w - 1)
                    guard box.mask(size: n) & covered == 0 else { continue }
                    // Very long thin strips make dull boards.
                    let thin = max(w, h) > 4 * min(w, h) ? 1 : 3
                    shapes.append(box)
                    shapeWeights.append(weights[area] * thin)
                }
            }
            guard !shapes.isEmpty else { return nil }
            let box = shapes[rng.weighted(shapeWeights)]
            boxes.append(box)
            covered |= box.mask(size: n)
        }
        return boxes
    }
}

/// A tiny lock so the cache is safe from the widget's intent and render
/// threads at once.
nonisolated final class Locked<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(_ value: Value) { self.value = value }

    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
