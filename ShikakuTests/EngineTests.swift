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

    @Test func allDifficultiesTurnUp() {
        let seen = Set((0..<60).map(Generator.difficulty(for:)))
        #expect(seen == Set(Difficulty.allCases))
    }

    @Test func drawingTheAnswerSolvesTheBoard() {
        let puzzle = Generator.make(day: 10, difficulty: .medium)
        var board = Board(day: 10)
        for box in puzzle.solution {
            board.tap(box.top * puzzle.size + box.left, puzzle: puzzle)
            board.tap(box.bottom * puzzle.size + box.right, puzzle: puzzle)
        }
        #expect(board.isSolved)
    }

    @Test func tapsDrawReplaceAndRemove() {
        let puzzle = Generator.make(day: 3, difficulty: .easy)
        var board = Board(day: 3)
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

    @Test func dayNumbersRoundTrip() {
        let today = Generator.day(for: .now)
        #expect(Generator.day(for: Generator.date(for: today)) == today)
        #expect(Generator.day(for: Generator.date(for: today + 1)) == today + 1)
    }
}
