import SwiftUI

struct VehicleView: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 7) {
                Text("以你的位置，定義好聲音。").font(.system(size: 25, weight: .semibold))
                Text(model.vehicle.name)
                    .font(.system(size: 13)).foregroundStyle(OrcaTheme.muted)
            }
            VehicleConfiguration(model: model)
            Panel {
                VStack(alignment: .leading, spacing: 20) {
                    HStack { Eyebrow(text: "LISTENING POSITION"); Spacer(); Tag(text: "配置預覽") }
                    HStack {
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 65).stroke(OrcaTheme.line, lineWidth: 2).frame(width: 190, height: 270)
                            RoundedRectangle(cornerRadius: 36).fill(OrcaTheme.blue.opacity(0.07)).frame(width: 150, height: 220)
                            VStack(spacing: 45) {
                                HStack(spacing: 60) {
                                    seatSymbol("駕駛座", symbol: "steeringwheel")
                                    seatSymbol("副駕駛", symbol: "person.fill")
                                }
                                HStack(spacing: 60) {
                                    seatSymbol("後座左", symbol: "person.fill")
                                    seatSymbol("後座右", symbol: "person.fill")
                                }
                            }
                            ForEach(0..<4, id: \.self) { i in
                                Image(systemName: "speaker.wave.2.fill").font(.system(size: 13)).foregroundStyle(OrcaTheme.cyan.opacity(0.7))
                                    .offset(x: i % 2 == 0 ? -100 : 100, y: i < 2 ? -78 : 76)
                            }
                        }.frame(width: 230, height: 290)
                        Spacer()
                    }.accessibilityElement(children: .contain)
                    Picker("聆聽位置", selection: $model.seat) {
                        ForEach(["駕駛座", "副駕駛", "後座左", "後座右"], id: \.self) { Text($0).tag($0) }
                    }.pickerStyle(.segmented)
                    Text("座位選擇僅用於配置預覽，不會自動套用聲音校正。")
                        .font(.system(size: 11)).foregroundStyle(OrcaTheme.muted)
                }
            }
            VehicleCalibration(model: model)
            Panel(padding: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("硬體連線").font(.system(size: 17, weight: .semibold))
                    connection("連線方式", value: model.vehicle.connection)
                    connection("App 處理通道", value: "左右立體聲")
                    connection("外接 DSP", value: "目前未安裝")
                    Text("Fiesta 目前以藍牙連接，無法獨立控制前後或分音單體。分音器仍負責分配高低頻；App 無法取代功率放大器或硬體主動分音。")
                        .font(.system(size: 11)).foregroundStyle(OrcaTheme.muted).padding(.top, 4)
                }
            }
        }
    }
    private func seatSymbol(_ seat: String, symbol: String) -> some View {
        Image(systemName: symbol).font(.system(size: 22))
            .foregroundStyle(model.seat == seat ? OrcaTheme.cyan : OrcaTheme.muted.opacity(0.45))
            .frame(width: 36, height: 45)
            .background(model.seat == seat ? OrcaTheme.blue.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel(seat)
    }
    private func connection(_ title: String, value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(OrcaTheme.muted) }.font(.system(size: 12))
    }
}
