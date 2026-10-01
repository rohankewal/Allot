import SwiftUI
import UIKit

@main
struct AllotApp: App {
    @AppStorage(Settings.Key.appearance, store: Settings.defaults)
    private var appearance: Appearance = .system

    var body: some Scene {
        WindowGroup {
            HomeView()
                .onAppear { AppearanceController.apply(appearance) }
                .onChange(of: appearance) { _, new in AppearanceController.apply(new) }
        }
    }
}

/// Sets light or dark on the app's windows. Done at the window rather than
/// with `preferredColorScheme`, which doesn't reliably go back to following
/// the system once it has been forced, and doesn't reach sheets.
enum AppearanceController {
    static func apply(_ appearance: Appearance) {
        for scene in UIApplication.shared.connectedScenes {
            guard let scene = scene as? UIWindowScene else { continue }
            for window in scene.windows {
                window.overrideUserInterfaceStyle = appearance.interfaceStyle
            }
        }
    }
}
