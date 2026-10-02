import SwiftUI
import UIKit
import WidgetKit

/// The whole app: what Allot is, how to play, how to add the widget, and
/// settings. The puzzle itself is only played in the widget, so there's no
/// board to play here, just a small example in the rules.
struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(Settings.Key.appearance, store: Settings.defaults) private var appearance: Appearance = .system
    @AppStorage(Settings.Key.difficulty, store: Settings.defaults) private var difficulty: DifficultyChoice = .daily
    @AppStorage(Settings.Key.showsFit, store: Settings.defaults) private var showsFit = true
    @AppStorage(Settings.Key.showsTime, store: Settings.defaults) private var showsTime = true
    @AppStorage(Settings.Key.reminderOn, store: Settings.defaults) private var reminderOn = false
    @AppStorage(Settings.Key.reminderMinutes, store: Settings.defaults) private var reminderMinutes = 9 * 60

    @State private var notificationsBlocked = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A new puzzle on your Home Screen every day.")
                            .font(.subheadline)
                            .foregroundStyle(Ink.secondary)
                        Text("Today: \(Copy.level(difficulty.resolve(day: GameStore.today)))")
                            .microLabelStyle(Ink.primary)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Line("Split the grid into boxes. Every box holds exactly one number, and that number is how many cells the box covers.")
                    ExampleBoard(showsFit: showsFit)
                        .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                    Line("Tap one corner of a box, then the opposite corner. Tap the first corner again to cancel.")
                    Line("Tap a box to remove it. A new box replaces any it overlaps.")
                    if showsFit {
                        Line("A dashed box is the wrong size or holds no number. You can turn the dashes off below.")
                    }
                    Line("Every box is at least two cells. A new puzzle arrives at midnight, finished or not.")
                } header: {
                    header("How to play")
                }

                Section {
                    Line("Touch and hold an empty part of your Home Screen until the apps jiggle.")
                    Line("Tap Edit, then Add Widget, and search for Allot.")
                    Line("Choose the large size and tap Add Widget.")
                } header: {
                    header("Add the widget")
                }

                Section {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                } header: {
                    header("Appearance")
                } footer: {
                    footer("Automatic follows your iPhone's light and dark setting. The widget matches.")
                }

                Section {
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(DifficultyChoice.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Mark wrong sizes", isOn: $showsFit)
                    Toggle("Show solve time", isOn: $showsTime)
                } header: {
                    header("Puzzle")
                } footer: {
                    footer(difficultyFooter)
                }

                Section {
                    Toggle("Daily reminder", isOn: $reminderOn)
                    if reminderOn {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    header("Reminder")
                } footer: {
                    footer(notificationsBlocked
                        ? "Notifications are off for this app. Turn them on in the Settings app, under Notifications."
                        : "A nudge to play, skipped on days you've already solved it.")
                }

                Section {
                    LabeledContent("Version", value: version)
                } footer: {
                    footer("Puzzles are made on your iPhone from the date. Nothing leaves your phone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Ink.canvas)
            .foregroundStyle(Ink.primary)
            .tint(Ink.primary)
            .navigationTitle("Allot")
        }
        .onChange(of: appearance) { reloadWidget() }
        .onChange(of: showsFit) { reloadWidget() }
        .onChange(of: showsTime) { reloadWidget() }
        .onChange(of: difficulty) {
            reloadWidget()
            Task { await Reminders.reschedule() }
        }
        .onChange(of: reminderMinutes) { Task { await Reminders.reschedule() } }
        .onChange(of: reminderOn) { _, on in
            Task {
                if on {
                    let allowed = await Reminders.requestPermission()
                    notificationsBlocked = !allowed
                    if !allowed { reminderOn = false }
                }
                await Reminders.reschedule()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Keeps 30 days of reminders queued, and drops today's if it
            // was solved in the widget.
            Task { await Reminders.reschedule() }
            // Back from the Settings app, maybe with notifications allowed.
            if notificationsBlocked {
                Task { notificationsBlocked = !(await Reminders.requestPermission()) }
            }
        }
    }

    // MARK: Pieces

    private var difficultyFooter: String {
        let base = difficulty == .daily
            ? "Daily mix picks easy (5×5), medium (6×6) or hard (7×7) at random each day."
            : "Every day's puzzle at this level. Everyone on the same level gets the same board."
        return base + " Changing this starts today's puzzle over."
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderMinutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        }
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func header(_ text: String) -> some View {
        Text(text).microLabelStyle()
    }

    private func footer(_ text: String) -> some View {
        Text(text).font(.footnote).foregroundStyle(Ink.secondary)
    }

    private func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: GameStore.widgetKind)
    }
}

/// A small 4×4 board, partly done, for the rules. Not playable, but a real
/// puzzle: it has exactly one answer.
private struct ExampleBoard: View {
    let showsFit: Bool

    private static let puzzle = Puzzle(
        day: 0,
        difficulty: .easy,
        size: 4,
        clues: [
            Clue(cell: 0, value: 4), Clue(cell: 2, value: 2), Clue(cell: 10, value: 4),
            Clue(cell: 12, value: 4), Clue(cell: 14, value: 2),
        ],
        solution: [
            Box(top: 0, left: 0, bottom: 1, right: 1), Box(top: 0, left: 2, bottom: 0, right: 3),
            Box(top: 1, left: 2, bottom: 2, right: 3), Box(top: 2, left: 0, bottom: 3, right: 1),
            Box(top: 3, left: 2, bottom: 3, right: 3),
        ]
    )

    private static var board: Board {
        var board = Board(for: puzzle)
        board.boxes = [
            Box(top: 0, left: 0, bottom: 1, right: 1),  // fits: 4 cells around the 4
            Box(top: 0, left: 2, bottom: 0, right: 3),  // fits: 2 cells around the 2
            Box(top: 1, left: 2, bottom: 1, right: 3),  // wrong: holds no number
        ]
        return board
    }

    var body: some View {
        BoardView(puzzle: Self.puzzle, board: Self.board, input: .display, showsFit: showsFit)
            .frame(maxWidth: 200)
            .frame(maxWidth: .infinity)
            .accessibilityElement()
            .accessibilityLabel("Example: a 4 by 4 grid with two boxes that fit and one that's the wrong size.")
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
