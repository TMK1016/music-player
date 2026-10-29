import SwiftUI
import Combine

@MainActor final class ValidationState: ObservableObject {
    @Published var result = "正在以離線音訊引擎驗證 EQ…"
}

@main struct AudioValidationApp: App {
    @StateObject private var state = ValidationState()
    var body: some Scene {
        WindowGroup("Orca 音訊驗證") {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("原生音訊驗證").font(.title2.bold())
                    Text(state.result).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    Text("只在記憶體中產生與處理音訊，不會播放至喇叭。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(28)
            }.frame(width: 650, height: 260)
                .task {
                    let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Offline audio validation")
                    defer { ProcessInfo.processInfo.endActivity(activity) }
                    do {
                        let legacy = try NativeEQChecks.run()
                        state.result = legacy + "\n" + (try await BassPlanChecks.run())
                    }
                    catch { state.result = "FAILED: " + String(describing: error) }
                    // Test-owned evidence path injected at compile time in the bundle plist.
                    if let path = Bundle.main.object(forInfoDictionaryKey: "ReportPath") as? String {
                        try? state.result.write(toFile: path, atomically: true, encoding: .utf8)
                    }
                }
        }
    }
}
