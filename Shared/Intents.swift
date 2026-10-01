import AppIntents
import Foundation

// The widget's buttons. They run in the widget's own process, save the
// move to the App Group, and WidgetKit redraws the widget afterwards.

nonisolated struct TapCellIntent: AppIntent {
    static let title: LocalizedStringResource = "Tap a cell"
    static let isDiscoverable = false

    @Parameter(title: "Cell") var cell: Int
    @Parameter(title: "Day") var day: Int

    init() {}

    init(cell: Int, day: Int) {
        self.cell = cell
        self.day = day
    }

    func perform() async throws -> some IntentResult {
        GameStore.tap(cell: cell, day: day)
        return .result()
    }
}

nonisolated struct ClearBoardIntent: AppIntent {
    static let title: LocalizedStringResource = "Clear the board"
    static let isDiscoverable = false

    @Parameter(title: "Day") var day: Int

    init() {}

    init(day: Int) {
        self.day = day
    }

    func perform() async throws -> some IntentResult {
        GameStore.clear(day: day)
        return .result()
    }
}
