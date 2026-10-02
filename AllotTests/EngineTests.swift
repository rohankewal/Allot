import Foundation
import Testing

struct EngineTests {
    /// A year of daily boards: each has one answer, needs no guessing, and
    /// comes out the same every time it's made.
    @Test func dailyBoardsAreFairAndStable() {
        for day in 0..<365 {
            let difficulty = Generator.difficulty(for: day)
            let puzzle = Generator.make(day: day, difficulty: difficulty)
            #expect(puzzle.size == difficulty.size)
            #expect(puzzle.isSolved(by: puzzle.solution))
            let report = Solver.analyse(puzzle)
            #expect(report.solutions == 1)
            #expect(report.technique != .guess)
            #expect(Generator.make(day: day, difficulty: difficulty) == puzzle)
        }
    }

    /// Every box is at least two cells: no 1s on any board.
    @Test func noSingleCellBoxes() {
        for day in 0..<365 {
            let puzzle = Generator.make(day: day, difficulty: Generator.difficulty(for: day))
            #expect(puzzle.clues.allSatisfy { $0.value >= 2 })
        }
    }

    @Test func tappingTheFirstCornerAgainCancels() {
        let puzzle = Generator.make(day: 3, difficulty: .easy)
        var board = Board(for: puzzle)
        board.tap(4, puzzle: puzzle)
        board.tap(4, puzzle: puzzle)
        #expect(board.anchor == nil && board.boxes.isEmpty)
    }

    @Test func allDifficultiesTurnUp() {
        let seen = Set((0..<60).map(Generator.difficulty(for:)))
        #expect(seen == Set(Difficulty.allCases))
    }

    @Test func drawingTheAnswerSolvesTheBoard() {
        let puzzle = Generator.make(day: 10, difficulty: .medium)
        var board = Board(for: puzzle)
        for box in puzzle.solution {
            board.tap(box.top * puzzle.size + box.left, puzzle: puzzle)
            board.tap(box.bottom * puzzle.size + box.right, puzzle: puzzle)
        }
        #expect(board.isSolved)
    }

    @Test func tapsDrawReplaceAndRemove() {
        let puzzle = Generator.make(day: 3, difficulty: .easy)
        var board = Board(for: puzzle)
        board.tap(0, puzzle: puzzle)
        #expect(board.anchor == 0)
        board.tap(6, puzzle: puzzle)                 // 2×2 in the corner
        #expect(board.boxes == [Box(top: 0, left: 0, bottom: 1, right: 1)])
        board.tap(1, puzzle: puzzle)                 // tap a box: removes it
        #expect(board.boxes.isEmpty)
        board.tap(6, puzzle: puzzle)
        board.tap(0, puzzle: puzzle)                 // corners either way round
        board.tap(2, puzzle: puzzle)
        board.tap(1, puzzle: puzzle)                 // overlaps: replaces it
        #expect(board.boxes == [Box(top: 0, left: 1, bottom: 0, right: 2)])
        board.tap(2, puzzle: puzzle)                 // tap a box: removes it
        #expect(board.boxes.isEmpty && board.anchor == nil)
    }

    @Test func fixedDifficultyGivesThatLevel() {
        for level in Difficulty.allCases {
            let puzzle = Generator.puzzle(for: 40, difficulty: level)
            #expect(puzzle.difficulty == level && puzzle.size == level.size)
        }
        // The daily mix's board is the same as that level's fixed board.
        let mixed = Generator.puzzle(for: 40)
        #expect(mixed == Generator.puzzle(for: 40, difficulty: mixed.difficulty))
    }

    @Test func boardsBelongToOneDayAndLevel() {
        let easy = Generator.puzzle(for: 5, difficulty: .easy)
        let hard = Generator.puzzle(for: 5, difficulty: .hard)
        #expect(Board(for: easy).belongs(to: easy))
        #expect(!Board(for: easy).belongs(to: hard))
    }

    @Test func placingReplacesOverlaps() {
        let puzzle = Generator.make(day: 3, difficulty: .easy)
        var board = Board(for: puzzle)
        let box = Box(top: 1, left: 1, bottom: 2, right: 3)
        board.place(box, puzzle: puzzle)
        #expect(board.boxes == [box])
        board.place(Box(top: 2, left: 0, bottom: 2, right: 1), puzzle: puzzle)  // overlaps: replaces
        #expect(board.boxes == [Box(top: 2, left: 0, bottom: 2, right: 1)])
        var solved = Board(for: puzzle)
        for b in puzzle.solution { solved.place(b, puzzle: puzzle) }
        #expect(solved.isSolved)
    }

    @Test func dayNumbersRoundTrip() {
        let today = Generator.day(for: .now)
        #expect(Generator.day(for: Generator.date(for: today)) == today)
        #expect(Generator.day(for: Generator.date(for: today + 1)) == today + 1)
    }
}
