import SwiftUI

struct VehicleConfiguration: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        Panel(padding: 22) {
            VStack(alignment: .leading, spacing: 16) {
                Text("音響配置").font(.headline)
                TextField("車輛名稱", text: $model.vehicle.name).textFieldStyle(.roundedBorder)
                Picker("連線方式", selection: $model.vehicle.connection) {
                    ForEach(["藍牙", "USB", "AUX", "CarPlay", "其他"], id: \.self) { Text($0).tag($0) }
                }
                Picker("前座左右", selection: $model.vehicle.front) {
                    ForEach(SpeakerType.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("後座左右", selection: $model.vehicle.rear) {
                    ForEach(SpeakerType.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("另有超低音", isOn: $model.vehicle.subwoofer)
                Text("目前登錄 \(model.vehicle.speakers.count) 個單體／總成位置。同軸是一個總成，內部可能有多個單體；位置數不代表獨立聲道數。").font(.caption).foregroundStyle(OrcaTheme.muted)
                ForEach(model.vehicle.speakers, id: \.self) { Text($0).font(.caption).foregroundStyle(OrcaTheme.cyan) }
            }
        }
    }
}
struct VehicleCalibration: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        Panel(padding: 22) {
            VStack(alignment: .leading, spacing: 16) {
                Text("聲道定位試音").font(.headline)
                Text("停車後測試，先降低車機音量。使用原創 2 秒測試音；暫停音樂並旁通音效，結束後不自動播放音樂。").font(.caption).foregroundStyle(OrcaTheme.muted)
                HStack {
                    Button("左聲道") { model.startChannelTest("Left") }
                    Button("右聲道") { model.startChannelTest("Right") }
                    Button("中央音像") { model.startChannelTest("Center") }
                    Button("停止") { model.stopChannelTest() }.disabled(model.activeChannelTest == nil)
                }.buttonStyle(.bordered)
                if let active = model.activeChannelTest { Text("試音中 · " + active).foregroundStyle(OrcaTheme.cyan) }
                Text("中央音像是左右同時播放，並非中央實體喇叭。車機可能將左右訊號分送前後，不能用來逐顆辨識高音喇叭；系統單聲道設定也會改變結果。").font(.caption).foregroundStyle(OrcaTheme.muted)
            }
        }.onDisappear { model.stopChannelTest() }
    }
}
