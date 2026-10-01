import AppIntents
import SwiftUI

/// The grid, shared by the widget and the app.
///
/// In the app, boxes are dragged out: press on one corner, drag to the
/// opposite one, let go. A live outline and size badge follow the finger.
/// A quick tap removes a box (or makes a 1×1 on an empty cell). VoiceOver
/// users draw with two taps instead, as on the widget.
///
/// In the widget each cell is a `Button(intent:)`, because widgets only take
/// taps: tap one corner, then the opposite one.
struct BoardView: View {
    enum Input {
        case intents
        case interactive(Interaction)
    }

    struct Interaction {
        var place: (Box) -> Void
        var quickTap: (Int) -> Void
        /// Two-tap drawing, for VoiceOver.
        var cornerTap: (Int) -> Void
        /// The box being dragged, or nil once the finger lifts.
        var onPreview: (Box?) -> Void = { _ in }
    }

    let puzzle: Puzzle
    let board: Board
    let input: Input
    /// When off, every box looks the same until the board is solved.
    var showsFit = true

    private struct DragState: Equatable {
        var start: Int
        var end: Int
        var moved: Bool
    }

    @GestureState private var drag: DragState?

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / CGFloat(puzzle.size)
            ZStack(alignment: .topLeading) {
                grid(cell: cell, side: side)
                ForEach(Array(board.boxes.enumerated()), id: \.offset) { _, box in
                    boxShape(box, cell: cell)
                }
                if let anchor = board.anchor {
                    anchorMark(anchor, cell: cell)
                }
                if let preview {
                    previewShape(preview, cell: cell)
                }
                ForEach(puzzle.clues, id: \.cell) { clue in
                    Text("\(clue.value)")
                        .font(.system(size: cell * 0.42, weight: .semibold).monospacedDigit())
                        .foregroundStyle(inverted(clue.cell) ? Ink.onAccent : Ink.primary)
                        .frame(width: cell, height: cell)
                        .offset(x: x(clue.cell, cell), y: y(clue.cell, cell))
                        .allowsHitTesting(false)
                }
                controls(cell: cell, side: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: preview) { _, box in
            if case .interactive(let interaction) = input { interaction.onPreview(box) }
        }
    }

    // MARK: Geometry

    private func x(_ index: Int, _ cell: CGFloat) -> CGFloat { CGFloat(index % puzzle.size) * cell }
    private func y(_ index: Int, _ cell: CGFloat) -> CGFloat { CGFloat(index / puzzle.size) * cell }

    private func cellAt(_ point: CGPoint, _ cell: CGFloat) -> Int {
        let n = puzzle.size
        let column = min(n - 1, max(0, Int(point.x / cell)))
        let row = min(n - 1, max(0, Int(point.y / cell)))
        return row * n + column
    }

    /// Boxes sit just inside their cells so neighbours read as separate.
    private let inset: CGFloat = 2.5
    private func radius(_ cell: CGFloat) -> CGFloat { max(4, cell * 0.14) }

    private var preview: Box? {
        guard let drag, drag.moved || drag.start != drag.end else { return nil }
        return Box(spanning: drag.start, drag.end, size: puzzle.size)
    }

    private func inverted(_ cell: Int) -> Bool {
        board.isSolved || board.anchor == cell
    }

    // MARK: Pieces

    /// A full grid: hairlines between cells, a firmer frame around the board,
    /// so it's easy to count how many cells a box covers.
    private func grid(cell: CGFloat, side: CGFloat) -> some View {
        let n = puzzle.size
        let frame = RoundedRectangle(cornerRadius: radius(cell) + inset, style: .continuous)
        return ZStack {
            frame.fill(Ink.canvas)
            Path { path in
                for i in 1..<n {
                    let v = CGFloat(i) * cell
                    path.move(to: CGPoint(x: v, y: 0))
                    path.addLine(to: CGPoint(x: v, y: side))
                    path.move(to: CGPoint(x: 0, y: v))
                    path.addLine(to: CGPoint(x: side, y: v))
                }
            }
            .stroke(Ink.line, lineWidth: 1)
            frame.strokeBorder(Ink.tertiary, lineWidth: 1.5)
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }

    private func place<V: View>(_ view: V, _ box: Box, cell: CGFloat) -> some View {
        view
            .padding(inset)
            .frame(width: CGFloat(box.width) * cell, height: CGFloat(box.height) * cell)
            .offset(x: CGFloat(box.left) * cell, y: CGFloat(box.top) * cell)
            .allowsHitTesting(false)
    }

    /// Fills are see-through so the grid lines (the cell count) stay
    /// visible inside a box until the board is solved.
    @ViewBuilder
    private func boxShape(_ box: Box, cell: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius(cell), style: .continuous)
        if board.isSolved {
            place(shape.fill(Ink.accent), box, cell: cell)
        } else if showsFit && !puzzle.isSatisfied(box) {
            place(
                shape.fill(Ink.primary.opacity(0.04))
                    .overlay(shape.strokeBorder(Ink.primary, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))),
                box, cell: cell
            )
        } else {
            place(
                shape.fill(Ink.primary.opacity(0.10))
                    .overlay(shape.strokeBorder(Ink.primary, lineWidth: 2)),
                box, cell: cell
            )
        }
    }

    /// The box under the finger, with its size in a badge on the corner.
    private func previewShape(_ box: Box, cell: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius(cell), style: .continuous)
        return place(
            shape.fill(Ink.primary.opacity(0.14))
                .overlay(shape.strokeBorder(Ink.primary, lineWidth: 2.5))
                .overlay(alignment: .topTrailing) {
                    Text("\(box.area)")
                        .font(.system(size: max(12, cell * 0.26), weight: .bold).monospacedDigit())
                        .foregroundStyle(Ink.onAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Ink.accent, in: Capsule())
                        .offset(x: 6, y: -10)
                },
            box, cell: cell
        )
    }

    private func anchorMark(_ index: Int, cell: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius(cell), style: .continuous)
            .fill(Ink.accent)
            .padding(inset)
            .frame(width: cell, height: cell)
            .offset(x: x(index, cell), y: y(index, cell))
            .allowsHitTesting(false)
    }

    // MARK: Input

    @ViewBuilder
    private func controls(cell: CGFloat, side: CGFloat) -> some View {
        switch input {
        case .intents:
            ForEach(0..<puzzle.cellCount, id: \.self) { index in
                Button(intent: TapCellIntent(cell: index, day: puzzle.day)) {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: cell, height: cell)
                .offset(x: x(index, cell), y: y(index, cell))
                .accessibilityLabel(accessibilityLabel(index))
            }
        case .interactive(let interaction):
            ZStack(alignment: .topLeading) {
                // One invisible element per cell for VoiceOver, which draws
                // with two taps. Touches pass through to the drag below.
                ForEach(0..<puzzle.cellCount, id: \.self) { index in
                    Color.clear
                        .frame(width: cell, height: cell)
                        .offset(x: x(index, cell), y: y(index, cell))
                        .accessibilityElement()
                        .accessibilityLabel(accessibilityLabel(index))
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { interaction.cornerTap(index) }
                }
            }
            .frame(width: side, height: side, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(dragGesture(cell: cell, interaction: interaction))
        }
    }

    private func dragGesture(cell: CGFloat, interaction: Interaction) -> some Gesture {
        // A press only counts as a drag once it has travelled a third of a
        // cell, so a shaky tap still reads as a tap.
        let threshold = cell * 0.33
        return DragGesture(minimumDistance: 0)
            .updating($drag) { value, state, _ in
                let distance = hypot(value.translation.width, value.translation.height)
                state = DragState(
                    start: cellAt(value.startLocation, cell),
                    end: cellAt(value.location, cell),
                    moved: (state?.moved ?? false) || distance > threshold
                )
            }
            .onEnded { value in
                let start = cellAt(value.startLocation, cell)
                let end = cellAt(value.location, cell)
                let distance = hypot(value.translation.width, value.translation.height)
                if start == end && distance <= threshold {
                    interaction.quickTap(start)
                } else {
                    interaction.place(Box(spanning: start, end, size: puzzle.size))
                }
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
