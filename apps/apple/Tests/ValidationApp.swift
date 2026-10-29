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
                    Text("使用合成訊號與靜音實際播放驗證，不會播放私人歌曲或輸出聲音。")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(28)
            }.frame(width: 650, height: 260)
                .task {
                    let activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Offline audio validation")
                    defer { ProcessInfo.processInfo.endActivity(activity) }
                    do {
                        FileHandle.standardError.write(Data("Stage: legacy EQ\n".utf8))
                        let legacy = try NativeEQChecks.run()
                        FileHandle.standardError.write(Data("Stage: legacy Bass A\n".utf8))
                        state.result = legacy + "\n" + (try await BassPlanChecks.run()) + "\n" + (try await V14Checks.run())
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
