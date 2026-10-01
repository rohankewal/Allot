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

    func place(_ box: Box) {
        change { $0.place(box, puzzle: puzzle) }
    }

    func quickTap(_ cell: Int) {
        change { $0.quickTap(cell, puzzle: puzzle) }
    }

    /// Two-tap drawing, used by VoiceOver.
    func cornerTap(_ cell: Int) {
        change { $0.tap(cell, puzzle: puzzle) }
    }

    private func change(_ body: (inout Board) -> Void) {
        refresh()
        let wasSolved = board.isSolved
        body(&board)
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
