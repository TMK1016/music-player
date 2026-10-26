import SwiftUI

@main struct OrcaPlayerApp: App {
    @StateObject private var model = PlayerModel(
        savedData: SettingsMigration.sourceData(),
        onSave: { UserDefaults.standard.set($0, forKey: "orca.ui.settings.v1") }
    )
    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .preferredColorScheme(.dark)
                .tint(OrcaTheme.blue)
                #if os(macOS)
                .frame(minWidth: 360, minHeight: 650)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1360, height: 920)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}

private enum SettingsMigration {
    static func sourceData() -> Data? {
        let defaults = UserDefaults.standard
        for key in ["orca.ui.settings.v1", "orca.ui.settings.before7band"] {
            if let original = defaults.data(forKey: key), let cleaned = try? PreferencesCleanup.removingVehicleData(original) {
                defaults.set(cleaned, forKey: key)
            }
        }
        let data = defaults.data(forKey: "orca.ui.settings.v1")
        if let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           (object["version"] as? Int ?? 1) < 3, defaults.data(forKey: "orca.ui.settings.before7band") == nil {
            defaults.set(data, forKey: "orca.ui.settings.before7band")
        }
        return data
    }
}
