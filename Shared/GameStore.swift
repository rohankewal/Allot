import Foundation

/// Today's board, shared by the app and the widget through the App Group.
/// Only one day is ever kept: at midnight yesterday's board, finished or
/// not, is simply replaced.
nonisolated enum GameStore {
    static let appGroup = "group.com.rohankewalramani.Shikaku"
    static let widgetKind = "ShikakuDaily"

    private static let boardKey = "board"
    private static let puzzlesKey = "puzzles"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    static var today: Int { Generator.day(for: .now) }

    // MARK: Puzzles

    /// Boards are made from the date, so this only saves the widget redoing
    /// the work each time it draws (a hard one can take a moment).
    static func puzzle(for day: Int) -> Puzzle {
        var saved = savedPuzzles()
        if let hit = saved.first(where: { $0.day == day }) { return hit }
        let made = Generator.puzzle(for: day)
        saved.append(made)
        saved = saved.filter { $0.day >= day - 1 && $0.day <= day + 1 }
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: puzzlesKey) }
        return made
    }

    private static func savedPuzzles() -> [Puzzle] {
        guard let data = defaults.data(forKey: puzzlesKey),
              let list = try? JSONDecoder().decode([Puzzle].self, from: data) else { return [] }
        return list
    }

    // MARK: Boards

    static func board(for day: Int) -> Board {
        guard let data = defaults.data(forKey: boardKey),
              let board = try? JSONDecoder().decode(Board.self, from: data),
              board.day == day else { return Board(day: day) }
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
        var board = board(for: day)
        board.tap(cell, puzzle: puzzle(for: day))
        save(board)
    }

    static func clear(day: Int) {
        guard day == today else { return }
        var board = board(for: day)
        board.clear()
        save(board)
    }
}
