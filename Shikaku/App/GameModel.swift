import Foundation
import Observation
import WidgetKit

/// The app's view of today's board. The widget can change the board while
/// the app is in the background, so this re-reads the store whenever the
/// app comes forward or the day turns over.
@Observable
final class GameModel {
    private(set) var puzzle: Puzzle
    private(set) var board: Board

    init() {
        let day = GameStore.today
        puzzle = GameStore.puzzle(for: day)
        board = GameStore.board(for: day)
    }

    func refresh() {
        let day = GameStore.today
        if puzzle.day != day { puzzle = GameStore.puzzle(for: day) }
        board = GameStore.board(for: day)
    }

    func tap(_ cell: Int) {
        refresh()
        board.tap(cell, puzzle: puzzle)
        commit()
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
