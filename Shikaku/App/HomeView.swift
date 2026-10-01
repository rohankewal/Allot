import Combine
import SwiftUI

/// The app is mostly a way to get the widget: today's puzzle (the same one,
/// kept in step with the widget), the rules, and how to add it.
struct HomeView: View {
    @State private var model = GameModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                game
                rules
                addWidget
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Ink.canvas)
        .foregroundStyle(Ink.primary)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            model.refresh()
        }
        .sensoryFeedback(.selection, trigger: model.board.boxes.count)
        .sensoryFeedback(.success, trigger: model.board.isSolved) { _, solved in solved }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Shikaku")
                .font(.system(size: 34, weight: .semibold))
                .tracking(-1.2)
            HStack(spacing: 8) {
                Text(model.puzzle.difficulty.title).microLabelStyle(Ink.primary)
                Text(Copy.date(model.puzzle.day)).microLabelStyle()
            }
        }
    }

    private var game: some View {
        VStack(spacing: 14) {
            BoardView(puzzle: model.puzzle, board: model.board, input: .action { cell in
                withAnimation(Motion.snap) { model.tap(cell) }
            })
            HStack(alignment: .firstTextBaseline) {
                Text(Copy.status(model.board, puzzle: model.puzzle))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(model.board.isSolved ? Ink.primary : Ink.secondary)
                Spacer()
                if !model.board.isEmpty && !model.board.isSolved {
                    Button("Clear") { withAnimation(Motion.snap) { model.clear() } }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Ink.primary)
                }
            }
            if model.board.isSolved {
                Text("A new puzzle arrives at midnight.")
                    .font(.footnote)
                    .foregroundStyle(Ink.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to play").microLabelStyle()
            Line("Split the grid into boxes. Every box holds exactly one number, and that number is how many cells the box covers.")
            Line("Tap a cell, then the opposite corner, to draw a box. Tap the same cell twice for a single square.")
            Line("A dashed box is the wrong size. Tap a box to remove it.")
            Line("Easy, medium or hard, chosen at random. A new puzzle every midnight, finished or not.")
        }
    }

    private var addWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add the widget").microLabelStyle()
            Line("Touch and hold an empty part of your Home Screen until the apps jiggle.")
            Line("Tap Edit, then Add Widget, and search for Shikaku.")
            Line("Choose the large size and tap Add Widget. You can play right there.")
        }
    }
}

private struct Line: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Ink.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    HomeView()
}
