import Foundation
import Observation
import WidgetKit

/// The app's view of today's board. The widget can change the board while
/// the app is in the background, so this re-reads the store whenever the
/// app comes forward, the day turns over, or a setting changes.
@Observable
final class GameModel {
    private(set) var puzzle: Puzzle
    private(set) var board: Board

    init() {
        let today = GameStore.puzzle(for: GameStore.today)
        puzzle = today
        board = GameStore.board(for: today)
    }

    func refresh() {
        puzzle = GameStore.puzzle(for: GameStore.today)
        board = GameStore.board(for: puzzle)
    }

    func tap(_ cell: Int) {
        refresh()
        let wasSolved = board.isSolved
        board.tap(cell, puzzle: puzzle)
        commit()
        if board.isSolved && !wasSolved { Reminders.cancel(day: puzzle.day) }
    }

    func clear() {
        refresh()
        board.clear()
        commit()
    }

    private func commit() {
        GameStore.save(board)
        WidgetCenter.shared.reloadTimelines(ofKind: GameStore.widgetKind)
    }
}
