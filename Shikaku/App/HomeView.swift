import Combine
import SwiftUI

/// Today's puzzle (the same one, kept in step with the widget). The rules
/// and how to add the widget live in Settings, so the board isn't inside a
/// scroll view that would fight the drag.
struct HomeView: View {
    @State private var model = GameModel()
    @State private var showingSettings = false
    @State private var dragging: Box?
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(Settings.Key.showsFit, store: Settings.defaults) private var showsFit = true
    @AppStorage(Settings.Key.showsTime, store: Settings.defaults) private var showsTime = true
    @AppStorage(Settings.Key.haptics, store: Settings.defaults) private var haptics = true

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header
            game
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Ink.canvas)
        .foregroundStyle(Ink.primary)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            model.refresh()
            // Keeps 30 days of reminders queued, and drops today's if the
            // puzzle was solved in the widget.
            Task { await Reminders.reschedule() }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView { model.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            model.refresh()
        }
        .sensoryFeedback(trigger: model.board.boxes) { _, _ in haptics ? .selection : nil }
        // A light tick each time the box under the finger changes size.
        .sensoryFeedback(trigger: dragging) { _, box in haptics && box != nil ? .impact(weight: .light, intensity: 0.6) : nil }
        .sensoryFeedback(trigger: model.board.isSolved) { _, solved in haptics && solved ? .success : nil }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Shikaku")
                    .font(.system(size: 34, weight: .semibold))
                    .tracking(-1.2)
                HStack(spacing: 8) {
                    Text(model.puzzle.difficulty.title).microLabelStyle(Ink.primary)
                    Text(Copy.date(model.puzzle.day)).microLabelStyle()
                }
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Ink.primary)
                    .frame(width: 40, height: 40)
                    .background(Ink.surface, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
    }

    private var game: some View {
        VStack(spacing: 14) {
            BoardView(
                puzzle: model.puzzle,
                board: model.board,
                input: .interactive(.init(
                    place: { box in withAnimation(Motion.snap) { model.place(box) } },
                    quickTap: { cell in withAnimation(Motion.snap) { model.quickTap(cell) } },
                    cornerTap: { cell in model.cornerTap(cell) },
                    onPreview: { dragging = $0 }
                )),
                showsFit: showsFit
            )
            HStack(alignment: .firstTextBaseline) {
                Text(Copy.status(model.board, puzzle: model.puzzle, showsTime: showsTime, showsFit: showsFit,
                                 dragging: dragging, byDragging: true))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(model.board.isSolved || dragging != nil ? Ink.primary : Ink.secondary)
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
}

#Preview {
    HomeView()
}
