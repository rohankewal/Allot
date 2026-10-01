import SwiftUI
import UIKit
import WidgetKit

struct SettingsView: View {
    /// Called when a change affects today's board.
    var onPuzzleChange: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(Settings.Key.appearance, store: Settings.defaults) private var appearance: Appearance = .system
    @AppStorage(Settings.Key.difficulty, store: Settings.defaults) private var difficulty: DifficultyChoice = .daily
    @AppStorage(Settings.Key.showsFit, store: Settings.defaults) private var showsFit = true
    @AppStorage(Settings.Key.showsTime, store: Settings.defaults) private var showsTime = true
    @AppStorage(Settings.Key.haptics, store: Settings.defaults) private var haptics = true
    @AppStorage(Settings.Key.reminderOn, store: Settings.defaults) private var reminderOn = false
    @AppStorage(Settings.Key.reminderMinutes, store: Settings.defaults) private var reminderMinutes = 9 * 60

    @State private var notificationsBlocked = false

    var body: some View {
        NavigationStack {
            Form {
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
                    Toggle("Haptics", isOn: $haptics)
                } header: {
                    header("Feel")
                } footer: {
                    footer("A light tap as you draw boxes in the app. Widgets can't vibrate.")
                }

                Section {
                    Line("Split the grid into boxes. Every box holds exactly one number, and that number is how many cells the box covers.")
                    Line("In the app, drag from one corner of a box to the opposite corner. Tap a box to remove it.")
                    Line("On the widget, tap one corner, then the opposite corner. Widgets can't follow a drag.")
                    Line("A dashed box is the wrong size. You can turn the dashes off above.")
                    Line("A new puzzle every midnight, finished or not.")
                } header: {
                    header("How to play")
                }

                Section {
                    Line("Touch and hold an empty part of your Home Screen until the apps jiggle.")
                    Line("Tap Edit, then Add Widget, and search for Allot.")
                    Line("Choose the large size and tap Add Widget. You can play right there.")
                } header: {
                    header("Add the widget")
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
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .onChange(of: appearance) { reloadWidget() }
        .onChange(of: showsFit) { reloadWidget() }
        .onChange(of: showsTime) { reloadWidget() }
        .onChange(of: difficulty) {
            onPuzzleChange()
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
            // Back from the Settings app, maybe with notifications allowed.
            if phase == .active && notificationsBlocked {
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
    SettingsView()
}
