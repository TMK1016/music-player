import SwiftUI

struct EqualizerCard: View {
    @ObservedObject var model: PlayerModel
    var condensed = false
    var isPlaybackPanel = false
    var body: some View {
        Panel(padding: 14) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Eyebrow(text: "SCULPT YOUR SOUND")
                        Text("喇叭等化器").font(.system(size: 19, weight: .semibold))
                    }
                    Spacer()
                    Toggle("等化器設定", isOn: $model.eqEnabled).labelsHidden().toggleStyle(.switch).scaleEffect(0.85, anchor: .trailing)
                }
                HStack {
                    Text("立體聲 / 7 段").font(.system(size: 11)).foregroundStyle(OrcaTheme.muted)
                    Spacer()
                    Text(model.eqEnabled ? model.presetName : "旁通").font(.system(size: 11, weight: .medium)).foregroundStyle(OrcaTheme.cyan)
                }
                EQCurve(gains: model.eqEnabled ? model.gains : EQBands.flat)
                    .frame(height: condensed ? 80 : 120)
                    .accessibilityLabel("等化器增益示意線，並非量測頻率響應")
                bandControls
                if model.hasManualEQChanges {
                    HStack {
                        Text(model.customPresets.count >= 20 ? "自訂模式已達 20 組，可覆蓋或刪除舊模式。" : "調音已變更").font(.caption).foregroundStyle(OrcaTheme.muted)
                        Spacer(minLength: 8)
                        Button("儲存新模式") { model.editPreset() }
                            .buttonStyle(.borderedProminent).disabled(model.customPresets.count >= 20)
                    }
                }
                ModeSelectionStrip(model: model, useSongPolicy: isPlaybackPanel)
                HStack {
                    Text(String(format: "前級餘裕 %+.1f dB", model.headroomDB)).font(.system(size: 10)).foregroundStyle(OrcaTheme.muted)
                    Spacer()
                    if condensed {
                        Button { model.page = .equalizer } label: { Label("細緻調音", systemImage: "arrow.up.right").font(.system(size: 11, weight: .medium)) }
                            .buttonStyle(.plain).foregroundStyle(OrcaTheme.cyan)
                    } else {
                        Button("全部歸零") { model.resetEQ() }.font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(OrcaTheme.cyan)
                    }
                }
            }
        }
    }

    private var bandControls: some View {
        GeometryReader { geometry in
            let columnWidth = geometry.size.width / CGFloat(EQBands.count)
            let trackHeight: CGFloat = condensed ? 110 : 150
            HStack(spacing: 0) {
                ForEach(0..<EQBands.count, id: \.self) { index in
                    VStack(spacing: 9) {
                        Text(String(format: "%+.1f", model.gains[index]))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(model.eqEnabled ? OrcaTheme.cyan : OrcaTheme.muted)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Slider(value: Binding(get: { model.gains[index] }, set: { model.adjustBand(index, to: $0) }), in: -12...12, step: 0.5)
                            .frame(width: trackHeight, height: 28).rotationEffect(.degrees(-90))
                            .frame(width: columnWidth, height: trackHeight)
                            .accessibilityLabel("\(Int(EQBands.frequencies[index])) Hz 增益")
                            .accessibilityValue(String(format: "%.1f dB", model.gains[index]))
                            .disabled(!model.eqEnabled)
                        Text(PlayerModel.frequencies[index]).font(.system(size: 10, design: .monospaced)).foregroundStyle(OrcaTheme.muted)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }.frame(width: columnWidth)
                }
            }
        }.frame(height: condensed ? 155 : 195)
            .accessibilityElement(children: .contain).accessibilityLabel("7 段等化器，固定顯示全部頻段")
    }

}

struct EQCurve: View {
    let gains: [Double]
    var body: some View {
        Canvas { context, size in
            let top: CGFloat = 12
            let plotHeight = size.height - 29
            let startX: CGFloat = 30
            let plotWidth = size.width - startX - 6
            for row in 0..<5 {
                let y = top + CGFloat(row) / 4 * plotHeight
                var path = Path(); path.move(to: CGPoint(x: startX, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(OrcaTheme.line), style: StrokeStyle(lineWidth: 0.6, dash: row == 2 ? [] : [2, 4]))
            }
            for (i, text) in ["+12", "0", "−12"].enumerated() {
                context.draw(Text(text).font(.system(size: 8, design: .monospaced)).foregroundStyle(OrcaTheme.muted), at: CGPoint(x: 11, y: top + CGFloat(i) / 2 * plotHeight))
            }
            var line = Path()
            var points: [CGPoint] = []
            for i in 0..<gains.count {
                let p = CGPoint(x: startX + CGFloat(i) / CGFloat(max(1, gains.count - 1)) * plotWidth, y: top + plotHeight / 2 - CGFloat(gains[i]) / 24 * plotHeight)
                points.append(p)
                if i == 0 { line.move(to: p) } else { line.addLine(to: p) }
            }
            if let first = points.first, let last = points.last {
                var area = line
                area.addLine(to: CGPoint(x: last.x, y: top + plotHeight)); area.addLine(to: CGPoint(x: first.x, y: top + plotHeight)); area.closeSubpath()
                context.fill(area, with: .linearGradient(Gradient(colors: [OrcaTheme.blue.opacity(0.25), OrcaTheme.blue.opacity(0.01)]), startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
            }
            context.stroke(line, with: .color(OrcaTheme.cyan), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            for p in points { context.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(OrcaTheme.cyan)) }
            for (index, text) in [(0, "50 Hz"), (3, "800"), (6, "12.5k Hz")] {
                let x = startX + CGFloat(index) / CGFloat(max(1, gains.count - 1)) * plotWidth
                context.draw(Text(text).font(.system(size: 8, design: .monospaced)).foregroundStyle(OrcaTheme.muted), at: CGPoint(x: min(size.width - 30, max(45, x)), y: size.height - 3))
            }
        }
    }
}

struct EqualizerPage: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 7) {
                Text("讓每個頻段，都恰到好處。").font(.system(size: 25, weight: .semibold))
                Text("調整你的聆聽偏好，或從一組預設開始。")
                    .font(.system(size: 13)).foregroundStyle(OrcaTheme.muted)
            }
            EqualizerCard(model: model)
            ProfileControls(model: model)
            Panel(padding: 20) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "hifispeaker.2").font(.system(size: 24)).foregroundStyle(OrcaTheme.cyan)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("目前介面：左右聲道整體調音").font(.system(size: 14, weight: .medium))
                        Text("EQ 已套用至本 App 的音訊。旁通會停用濾波，並保留前級補償；曲線是設定示意，並非量測響應。可加上低音增強與立體聲殘響；逐喇叭處理需要獨立硬體通道。")
                            .font(.system(size: 12)).foregroundStyle(OrcaTheme.muted).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
