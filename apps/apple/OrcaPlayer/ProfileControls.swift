import SwiftUI

struct ProfileControls: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        Panel(padding: 22) {
            VStack(alignment: .leading, spacing: 18) {
                Text("低音與空間").font(.headline)
                HStack { Text("低音增強 · 90 Hz 低架濾波"); Spacer(); Text(String(format: "+%.1f dB", model.bassBoost)).foregroundStyle(OrcaTheme.cyan) }.font(.caption)
                Slider(value: $model.bassBoost, in: 0...9, step: 0.5).disabled(!model.eqEnabled)
                Picker("空間風格", selection: $model.ambience) {
                    ForEach(Ambience.allCases) { Text($0.rawValue).tag($0) }
                }.disabled(!model.eqEnabled)
                HStack { Text("殘響混合"); Spacer(); Text(String(format: "%.0f%%", model.ambienceMix)) }.font(.caption)
                Slider(value: $model.ambienceMix, in: 0...35, step: 1).disabled(!model.eqEnabled || model.ambience == .off)
                Text("空間風格使用立體聲殘響模擬，不是 Dolby 或獨立多聲道環繞。低音增強會預留前級餘裕，不能增加喇叭本身的低頻能力。夜間模式只調整音色，不包含動態壓縮。").font(.caption).foregroundStyle(OrcaTheme.muted)
            }
        }
        Panel(padding: 22) {
            VStack(alignment: .leading, spacing: 18) {
                Text("歌曲自動套用").font(.headline)
                Text(model.track.title).font(.subheadline).foregroundStyle(OrcaTheme.muted)
                Picker("此歌曲的模式", selection: Binding(get: { model.songBindings[model.selectedID] ?? "" }, set: { model.bindSong(to: $0) })) {
                    Text("無綁定 · 使用一般調音").tag("")
                    ForEach(model.modeOptions) { Text($0.name).tag($0.id) }
                }
                Text("切到已綁定的歌曲時自動套用；切到未綁定歌曲時恢復先前的一般調音。手動選模式會更新一般調音，綁定仍保留；重新進入已綁定歌曲時會再次自動套用。").font(.caption).foregroundStyle(OrcaTheme.muted)
            }
        }
        Panel(padding: 22) {
            VStack(alignment: .leading, spacing: 12) {
                Text("7 段頻率如何劃分？").font(.headline)
                Text("50 Hz 調整低頻重量，125 Hz 調整厚度，315 Hz 調整溫暖與混濁感，800 Hz 調整中頻，2k Hz 調整人聲存在感，5k Hz 調整清晰度，12.5k Hz 調整高頻亮度。").font(.subheadline)
                Text("各段中心頻率以接近等比例分佈，頻寬約 1⅓ 倍頻程，彼此平順重疊；不是分頻器，也不是音質等級。dB 往上會增強附近頻率，往下則削減；頻帶彼此重疊，不代表把音樂分配給某一顆喇叭。先每次調整 1～2 dB，避免同時拉高全部頻段。").font(.caption).foregroundStyle(OrcaTheme.muted)
            }
        }
    }
}

struct SongBindingEditor: View {
    @ObservedObject var model: PlayerModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("目前歌曲") {
                    Text(model.title(model.track))
                    Toggle("依歌曲套用音效", isOn: Binding(get: { model.useSongProfiles }, set: { model.setSongProfilePolicy($0) }))
                    Picker("歌曲音效模式", selection: Binding(get: { model.songBindings[model.selectedID] ?? "" }, set: { model.bindSong(to: $0) })) {
                        Text("無綁定，使用一般調音").tag("")
                        ForEach(model.modeOptions) { Text($0.name).tag($0.id) }
                    }
                }
            }.scrollContentBackground(.hidden).navigationTitle("歌曲音效綁定")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 300, minHeight: 300).themedSheet()
    }
}
