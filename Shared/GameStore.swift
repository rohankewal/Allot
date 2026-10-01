import Foundation

/// Today's board, shared by the app and the widget through the App Group.
/// Only one board is ever kept: at midnight yesterday's board, finished or
/// not, is simply replaced.
nonisolated enum GameStore {
    static let widgetKind = "ShikakuDaily"

    private static let boardKey = "board"
    private static let puzzlesKey = "puzzles"

    private static var defaults: UserDefaults { Settings.defaults }

    static var today: Int { Generator.day(for: .now) }

    // MARK: Puzzles

    /// The day's puzzle at the difficulty chosen in Settings.
    static func puzzle(for day: Int) -> Puzzle {
        puzzle(for: day, difficulty: Settings.difficulty.resolve(day: day))
    }

    /// Boards are made from the date, so saving them only spares the widget
    /// redoing the work each time it draws (a hard one can take a moment).
    static func puzzle(for day: Int, difficulty: Difficulty) -> Puzzle {
        var saved = savedPuzzles()
        if let hit = saved.first(where: { $0.day == day && $0.difficulty == difficulty }) { return hit }
        let made = Generator.puzzle(for: day, difficulty: difficulty)
        saved.append(made)
        saved = saved.filter { $0.day >= day - 1 && $0.day <= day + 1 }.suffix(6)
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: puzzlesKey) }
        return made
    }

    private static func savedPuzzles() -> [Puzzle] {
        guard let data = defaults.data(forKey: puzzlesKey),
              let list = try? JSONDecoder().decode([Puzzle].self, from: data) else { return [] }
        return list
    }

    // MARK: Boards

    /// The saved board if it's for this puzzle, otherwise a fresh one.
    static func board(for puzzle: Puzzle) -> Board {
        guard let data = defaults.data(forKey: boardKey),
              let board = try? JSONDecoder().decode(Board.self, from: data),
              board.belongs(to: puzzle) else { return Board(for: puzzle) }
        return board
    }

    static func save(_ board: Board) {
        if let data = try? JSONEncoder().encode(board) { defaults.set(data, forKey: boardKey) }
    }

    // MARK: Moves

    /// `day` is the day the tapped widget was showing. A tap that lands just
    /// after midnight on yesterday's board is dropped rather than applied to
    /// today's.
    static func tap(cell: Int, day: Int) {
        guard day == today else { return }
        let puzzle = puzzle(for: day)
        var board = board(for: puzzle)
        let wasSolved = board.isSolved
        board.tap(cell, puzzle: puzzle)
        save(board)
        if board.isSolved && !wasSolved { Reminders.cancel(day: day) }
    }

    static func clear(day: Int) {
        guard day == today else { return }
        let puzzle = puzzle(for: day)
        var board = board(for: puzzle)
        board.clear()
        save(board)
    }
}
