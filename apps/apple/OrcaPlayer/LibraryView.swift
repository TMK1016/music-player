import SwiftUI

struct TrackRow: View {
    @ObservedObject var model: PlayerModel
    let track: AudioTrack
    var body: some View {
        HStack(spacing: 12) {
            Button { model.choose(track) } label: {
                HStack(spacing: 12) {
                    AlbumArtwork(variant: track.artwork, compact: true).frame(width: 45)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title).font(.system(size: 13, weight: .medium)).foregroundStyle(model.track.id == track.id ? OrcaTheme.cyan : OrcaTheme.text).lineLimit(1)
                        Text(track.artist).font(.system(size: 11)).foregroundStyle(OrcaTheme.muted).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(PlayerModel.time(track.duration)).font(.system(size: 11, design: .monospaced)).foregroundStyle(OrcaTheme.muted)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("播放 \(track.title)")
            IconButton(symbol: model.favorites.contains(track.id) ? "heart.fill" : "heart", label: "切換 \(track.title) 收藏", active: model.favorites.contains(track.id), size: 36) { model.toggleFavorite(track) }
        }.padding(10).background(model.track.id == track.id ? OrcaTheme.blue.opacity(0.07) : OrcaTheme.panel.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct LibraryView: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("下一段旅程，聽什麼？").font(.system(size: 25, weight: .semibold))
                    Text("匯入自己的音檔，離線也能自在聆聽。")
                        .font(.system(size: 12)).foregroundStyle(OrcaTheme.muted)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                Button { model.showImporter = true } label: {
                    Label(model.isImporting ? "正在匯入…" : "匯入音樂", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(OrcaTheme.text)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(OrcaTheme.blue, in: Capsule())
                }.buttonStyle(.plain).disabled(model.isImporting)
                if model.isImporting { ProgressView().controlSize(.small) }
            }
            if !model.importSummary.isEmpty { Text(model.importSummary).font(.system(size: 12)).foregroundStyle(OrcaTheme.cyan) }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(OrcaTheme.muted)
                TextField("搜尋歌曲、演出者或專輯", text: $model.search).textFieldStyle(.plain).font(.system(size: 13))
                if !model.search.isEmpty {
                    Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("清除搜尋")
                }
            }.padding(14).background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 9) {
                filter("全部歌曲", enabled: !model.favoritesOnly) { model.favoritesOnly = false }
                filter("我的收藏", enabled: model.favoritesOnly) { model.favoritesOnly = true }
                Spacer()
                Text("\(model.filteredTracks.count) 首").font(.system(size: 11)).foregroundStyle(OrcaTheme.muted)
            }
            if model.filteredTracks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list").font(.system(size: 32)).foregroundStyle(OrcaTheme.cyan)
                    Text("沒有符合的歌曲").font(.system(size: 16, weight: .medium))
                    Text("試試其他關鍵字，或切換至全部歌曲。")
                        .font(.system(size: 12)).foregroundStyle(OrcaTheme.muted)
                }.frame(maxWidth: .infinity).padding(.vertical, 45)
            } else {
                VStack(spacing: 8) {
                    ForEach(model.filteredTracks) { track in TrackRow(model: model, track: track) }
                }
            }
            Text("音樂來源").font(.system(size: 17, weight: .semibold)).padding(.top, 10)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { sourceCards }
                VStack(spacing: 12) { sourceCards }
            }
        }
    }
    private func filter(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .medium)).padding(.horizontal, 13).padding(.vertical, 9)
                .foregroundStyle(enabled ? OrcaTheme.cyan : OrcaTheme.muted)
                .background(enabled ? OrcaTheme.blue.opacity(0.18) : OrcaTheme.panel, in: Capsule())
        }.buttonStyle(.plain)
    }
    @ViewBuilder private var sourceCards: some View {
        sourceCard("本機音樂", symbol: "folder", caption: "複製匯入，保留原始檔案", message: nil)
        sourceCard("iCloud Drive", symbol: "icloud", caption: "讓收藏隨你同行", message: "iCloud Drive 選檔、下載與保留離線副本尚未接入。")
        sourceCard("來源連結", symbol: "link", caption: "收藏喜歡的音樂來源", message: "來源連結收藏尚未接入。YouTube 音樂下載需要符合平台授權，這裡不提供擷取功能。")
    }
    private func sourceCard(_ title: String, symbol: String, caption: String, message: String?) -> some View {
        Button { if let message { model.message = message } else { model.showImporter = true } } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Image(systemName: symbol).font(.system(size: 21)).foregroundStyle(OrcaTheme.cyan); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(OrcaTheme.muted) }
                Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(OrcaTheme.text)
                Text(caption).font(.system(size: 11)).foregroundStyle(OrcaTheme.muted)
                Text(message == nil ? "可離線" : "待接入").font(.system(size: 10)).foregroundStyle(OrcaTheme.muted)
            }.padding(18).frame(minWidth: 180, maxWidth: .infinity, alignment: .leading).background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain)
    }
}

struct QueueView: View {
    @ObservedObject var model: PlayerModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("播放佇列").font(.title2.weight(.semibold)); Spacer(); Button("完成") { dismiss() }.buttonStyle(.plain).foregroundStyle(OrcaTheme.cyan) }
            Text("\(model.tracks.count) 首 · 選擇歌曲開始播放").font(.system(size: 12)).foregroundStyle(OrcaTheme.muted)
            ScrollView { VStack(spacing: 8) { ForEach(model.tracks) { TrackRow(model: model, track: $0) } } }
        }.padding(24).frame(minWidth: 300, idealWidth: 480, minHeight: 400)
            .background(OrcaTheme.background).foregroundStyle(OrcaTheme.text).preferredColorScheme(.dark)
    }
}
