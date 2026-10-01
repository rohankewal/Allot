import AppIntents
import SwiftUI

/// The grid, shared by the widget and the app. In the widget each cell is a
/// `Button(intent:)`; in the app it's an ordinary button.
struct BoardView: View {
    enum Input {
        /// Widget: taps run `TapCellIntent` for this day.
        case intents
        /// App: taps call back directly.
        case action((Int) -> Void)
    }

    let puzzle: Puzzle
    let board: Board
    let input: Input
    /// When off, every box looks the same until the board is solved.
    var showsFit = true

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(puzzle.size)
            ZStack(alignment: .topLeading) {
                gridLines(cell: cell, side: side)
                ForEach(Array(board.boxes.enumerated()), id: \.offset) { _, box in
                    boxShape(box, cell: cell)
                }
                if let anchor = board.anchor {
                    RoundedRectangle(cornerRadius: corner(cell), style: .continuous)
                        .fill(Ink.accent)
                        .padding(inset(cell))
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(anchor % puzzle.size) * cell, y: CGFloat(anchor / puzzle.size) * cell)
                }
                ForEach(puzzle.clues, id: \.cell) { clue in
                    Text("\(clue.value)")
                        .font(.system(size: cell * 0.44, weight: .semibold).monospacedDigit())
                        .foregroundStyle(inverted(clue.cell) ? Ink.onAccent : Ink.primary)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(clue.cell % puzzle.size) * cell, y: CGFloat(clue.cell / puzzle.size) * cell)
                }
                ForEach(0..<puzzle.cellCount, id: \.self) { index in
                    tapTarget(index)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(index % puzzle.size) * cell, y: CGFloat(index / puzzle.size) * cell)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
    }

    // MARK: Pieces

    private func inset(_ cell: CGFloat) -> CGFloat { max(1.5, cell * 0.06) }
    private func corner(_ cell: CGFloat) -> CGFloat { cell * 0.2 }

    /// A dot at each inner grid corner plus a hairline frame: enough to count
    /// cells by without drawing a cage.
    private func gridLines(cell: CGFloat, side: CGFloat) -> some View {
        let n = puzzle.size
        return ZStack(alignment: .topLeading) {
            Path { path in
                for i in 0...n {
                    for j in 0...n {
                        let p = CGPoint(x: CGFloat(i) * cell, y: CGFloat(j) * cell)
                        path.addEllipse(in: CGRect(x: p.x - 1.25, y: p.y - 1.25, width: 2.5, height: 2.5))
                    }
                }
            }
            .fill(Ink.line)
        }
        .frame(width: side, height: side, alignment: .topLeading)
    }

    @ViewBuilder
    private func boxShape(_ box: Box, cell: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner(cell), style: .continuous)
        let fits = puzzle.isSatisfied(box)
        Group {
            if board.isSolved {
                shape.fill(Ink.accent)
            } else if !showsFit {
                shape.strokeBorder(Ink.primary, lineWidth: 1.5)
            } else if fits {
                shape.fill(Ink.surfaceHigh)
                    .overlay(shape.strokeBorder(Ink.primary, lineWidth: 1.5))
            } else {
                shape.strokeBorder(Ink.primary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
        }
        .padding(inset(cell))
        .frame(width: CGFloat(box.width) * cell, height: CGFloat(box.height) * cell)
        .offset(x: CGFloat(box.left) * cell, y: CGFloat(box.top) * cell)
    }

    private func inverted(_ cell: Int) -> Bool {
        board.isSolved || board.anchor == cell
    }

    @ViewBuilder
    private func tapTarget(_ index: Int) -> some View {
        let label = Color.clear.contentShape(Rectangle())
        switch input {
        case .intents:
            Button(intent: TapCellIntent(cell: index, day: puzzle.day)) { label }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(index))
        case .action(let tap):
            Button { tap(index) } label: { label }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(index))
        }
    }

    private func accessibilityLabel(_ index: Int) -> String {
        let row = index / puzzle.size + 1, column = index % puzzle.size + 1
        var parts = ["Row \(row), column \(column)"]
        if let clue = puzzle.clue(at: index) { parts.append("number \(clue.value)") }
        if board.anchor == index { parts.append("first corner") }
        if let box = board.boxes.first(where: { $0.contains(index, size: puzzle.size) }) {
            parts.append("in a \(box.width) by \(box.height) box")
        }
        return parts.joined(separator: ", ")
    }
}
