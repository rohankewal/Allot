import AppIntents
import SwiftUI
import WidgetKit

@main
struct ShikakuWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyShikakuWidget()
    }
}

// MARK: - Timeline

struct PuzzleEntry: TimelineEntry {
    let date: Date
    let puzzle: Puzzle
    let board: Board
    var appearance: Appearance = Settings.appearance
    var showsFit: Bool = Settings.showsFit
    var showsTime: Bool = Settings.showsTime
}

/// Two entries: the board as it stands now, and a fresh one at midnight.
/// The new puzzle arrives whether or not today's was touched, and the
/// timeline asks to be rebuilt once that midnight entry is showing.
struct PuzzleProvider: TimelineProvider {
    func placeholder(in context: Context) -> PuzzleEntry {
        sample()
    }

    func getSnapshot(in context: Context, completion: @escaping (PuzzleEntry) -> Void) {
        if context.isPreview {
            completion(sample())
        } else {
            completion(entry(for: GameStore.today, at: .now))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PuzzleEntry>) -> Void) {
        let today = GameStore.today
        let midnight = Generator.date(for: today + 1)
        let entries = [
            entry(for: today, at: .now),
            entry(for: today + 1, at: midnight),
        ]
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(for day: Int, at date: Date) -> PuzzleEntry {
        let puzzle = GameStore.puzzle(for: day)
        return PuzzleEntry(date: date, puzzle: puzzle, board: GameStore.board(for: puzzle))
    }

    /// For the widget gallery: today's board with a few boxes already in, so
    /// it reads as a game rather than a grid of numbers.
    private func sample() -> PuzzleEntry {
        let puzzle = GameStore.puzzle(for: GameStore.today)
        return PuzzleEntry(date: .now, puzzle: puzzle, board: .partial(puzzle, boxes: max(2, puzzle.solution.count / 3)))
    }
}

// MARK: - Widget

struct DailyShikakuWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: GameStore.widgetKind, provider: PuzzleProvider()) { entry in
            DailyShikakuView(entry: entry)
                .containerBackground(Ink.canvas, for: .widget)
                .appearance(entry.appearance)
        }
        .configurationDisplayName("Daily Shikaku")
        .description("A new puzzle every day. Divide the grid into boxes, each holding one number equal to its size.")
        .supportedFamilies([.systemLarge])
    }
}

struct DailyShikakuView: View {
    let entry: PuzzleEntry

    private var puzzle: Puzzle { entry.puzzle }
    private var board: Board { entry.board }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(puzzle.difficulty.title).microLabelStyle(Ink.primary)
                Spacer()
                Text(Copy.date(puzzle.day)).microLabelStyle()
            }

            BoardView(puzzle: puzzle, board: board, input: .intents, showsFit: entry.showsFit)

            HStack(alignment: .firstTextBaseline) {
                Text(Copy.status(board, puzzle: puzzle, showsTime: entry.showsTime, showsFit: entry.showsFit))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(board.isSolved ? Ink.primary : Ink.secondary)
                    .contentTransition(.opacity)
                Spacer()
                if !board.isEmpty && !board.isSolved {
                    Button(intent: ClearBoardIntent(day: puzzle.day)) {
                        Text("Clear")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Ink.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(Ink.primary)
    }
}

#Preview(as: .systemLarge) {
    DailyShikakuWidget()
} timeline: {
    let puzzle = Generator.puzzle(for: Generator.day(for: .now))
    PuzzleEntry(date: .now, puzzle: puzzle, board: Board(for: puzzle))
    PuzzleEntry(date: .now, puzzle: puzzle, board: .partial(puzzle, boxes: 3), appearance: .dark)
    PuzzleEntry(date: .now, puzzle: puzzle, board: .partial(puzzle, boxes: 3))
}

extension Board {
    /// Part of the answer filled in, for previews.
    static func partial(_ puzzle: Puzzle, boxes count: Int) -> Board {
        var board = Board(for: puzzle)
        board.boxes = Array(puzzle.solution.prefix(count))
        return board
    }
}
