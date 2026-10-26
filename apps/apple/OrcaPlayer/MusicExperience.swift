import SwiftUI
import UniformTypeIdentifiers
import AVKit

// Explicit property-wrapper alias also supports SDKs that expose a same-name State macro.
typealias ViewState<Value> = State<Value>

struct MusicHomeView: View {
    @ObservedObject var model: PlayerModel
    @ViewState private var section = "播放清單"
    @ViewState private var playlist = "all"
    @ViewState private var newList = false
    @ViewState private var name = ""
    @ViewState private var expandedArtist: String?
    @ViewState private var artistSort = "歌曲數目"
    @ViewState private var monthly = true
    private let systems = [("favorites", "我的最愛"), ("recent", "最近新增"), ("stars5", "5顆星"), ("stars4", "4顆星"), ("stars3", "3顆星"), ("stars2", "2顆星"), ("stars1", "1顆星"), ("liked", "喜好歌曲"), ("unfamiliar", "陌生歌曲")]
    private var matching: [AudioTrack] {
        let source = section == "全部歌曲" ? model.tracks : model.songs(in: playlist)
        return source.filter { (!model.favoritesOnly || model.favorites.contains($0.id)) && (model.search.isEmpty || "\(model.title($0)) \(model.artist($0))".localizedCaseInsensitiveContains(model.search)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                TextField("搜尋歌曲或歌手", text: $model.search).textFieldStyle(.roundedBorder).onSubmit { model.recordSearch() }
                Button { model.showImporter = true } label: { Image(systemName: "square.and.arrow.down"); Text("匯入音樂") }.disabled(model.isImporting)
            }
            if !model.collection.searches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { Text("近期搜尋").font(.caption); ForEach(model.collection.searches, id: \.self) { query in Button(query) { model.search = query } }; Button("清除") { model.collection.searches = [] } }
                }
            }
            if !model.importSummary.isEmpty { Text(model.importSummary).font(.caption).foregroundStyle(OrcaTheme.cyan) }
            Picker("曲庫", selection: $section) { ForEach(["播放清單", "歌手列表", "全部歌曲"], id: \.self) { Text($0) } }.pickerStyle(.segmented)
                .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { drag in
                    guard abs(drag.translation.width) > abs(drag.translation.height) * 1.5 else { return }
                    let tabs = ["播放清單", "歌手列表", "全部歌曲"]
                    let i = tabs.firstIndex(of: section) ?? 0
                    section = tabs[min(2, max(0, i + (drag.translation.width < 0 ? 1 : -1)))]
                })
            if section == "播放清單" { playlists }
            if section == "歌手列表" { artists }
            else {
                if matching.isEmpty { Text("沒有符合的歌曲。未評分歌曲不納入喜好／陌生清單。").font(.caption).foregroundStyle(OrcaTheme.muted) }
                ForEach(matching) { track in CollectionSongRow(model: model, track: track, queue: matching, playlistID: playlist) }
            }
            Divider()
            HStack { Text("排行榜").font(.title3); Spacer(); Picker("排行榜範圍", selection: $monthly) { Text("當月").tag(true); Text("累計").tag(false) }.frame(maxWidth: 180) }
            Text("實際播放超過半首計1次，重播可再計。累計榜暫作第二種榜的實作解讀。").font(.caption).foregroundStyle(OrcaTheme.muted)
            let ranked = model.tracks.filter { model.playCount($0.id, monthly: monthly) > 0 }.sorted { let a = model.playCount($0.id, monthly: monthly), b = model.playCount($1.id, monthly: monthly); return a == b ? model.title($0) < model.title($1) : a > b }
            if ranked.isEmpty { Text("尚無達標播放紀錄").foregroundStyle(OrcaTheme.muted) }
            ForEach(Array(ranked.prefix(10).enumerated()), id: \.element.id) { index, track in
                HStack { Text("\(index + 1)").foregroundStyle(OrcaTheme.cyan); Button(model.title(track)) { model.play(track, queue: ranked) }; Spacer(); Text("\(model.playCount(track.id, monthly: monthly)) 次") }.padding(12).background(OrcaTheme.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
        }.sheet(isPresented: $newList) {
            VStack(spacing: 20) { Text("新增播放清單").font(.title2); TextField("清單名稱", text: $name).textFieldStyle(.roundedBorder); HStack { Button("取消") { newList = false }; Spacer(); Button("建立") { model.createPlaylist(name); newList = false } } }.padding(24).frame(minWidth: 280)
        }
    }
    private var orderedSystems: [(String, String)] {
        systems.sorted { a, b in (model.collection.playlistOrder.firstIndex(of: a.0) ?? (100 + systems.firstIndex { $0.0 == a.0 }!)) < (model.collection.playlistOrder.firstIndex(of: b.0) ?? (100 + systems.firstIndex { $0.0 == b.0 }!)) }
    }
    private func moveSystem(_ id: String, by offset: Int) {
        var ids = orderedSystems.map { $0.0 }
        guard let i = ids.firstIndex(of: id), ids.indices.contains(i + offset) else { return }
        ids.swapAt(i, i + offset); model.collection.playlistOrder = ids
    }
    private var playlists: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack { Button("全部") { playlist = "all"; model.favoritesOnly = false }; ForEach(orderedSystems, id: \.0) { id, title in Button(title) { playlist = id; model.favoritesOnly = false }.tint(playlist == id ? OrcaTheme.cyan : OrcaTheme.muted).contextMenu { Button("往前移") { moveSystem(id, by: -1) }; Button("往後移") { moveSystem(id, by: 1) } } } }
            }
            ForEach(model.collection.playlists) { list in
                HStack {
                    Button { playlist = list.id; model.favoritesOnly = false } label: { Label(list.name, systemImage: "music.note.list"); Text("\(list.trackIDs.count)").foregroundStyle(OrcaTheme.muted) }
                    Spacer()
                    Menu { Button("往上移") { moveList(list.id, by: -1) }; Button("往下移") { moveList(list.id, by: 1) }; Button("刪除清單（保留歌曲）", role: .destructive) { model.deletePlaylist(list.id); if playlist == list.id { playlist = "all" } } } label: { Image(systemName: "ellipsis") }
                }.padding(10).background(playlist == list.id ? OrcaTheme.blue.opacity(0.2) : OrcaTheme.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            }
            Button { name = ""; newList = true } label: { Label("新增播放清單", systemImage: "plus.circle") }
        }
    }
    private func moveList(_ id: String, by offset: Int) {
        guard let i = model.collection.playlists.firstIndex(where: { $0.id == id }), model.collection.playlists.indices.contains(i + offset) else { return }
        model.collection.playlists.swapAt(i, i + offset)
    }
    private var groups: [String] {
        let names = Set(model.tracks.filter { model.search.isEmpty || model.artist($0).localizedCaseInsensitiveContains(model.search) || model.title($0).localizedCaseInsensitiveContains(model.search) }.map { model.artist($0) })
        return names.sorted { a, b in
            let left = model.tracks.filter { model.artist($0) == a }, right = model.tracks.filter { model.artist($0) == b }
            if artistSort == "歌曲數目", left.count != right.count { return left.count > right.count }
            if artistSort == "喜好高低" {
                @MainActor func mean(_ songs: [AudioTrack]) -> Double { let values = songs.map { model.rating($0.id) }.filter { $0 > 0 }; return values.isEmpty ? 0 : Double(values.reduce(0,+)) / Double(values.count) }
                let x = mean(left), y = mean(right); if x != y { return x > y }
            }
            return a.compare(b, options: [.numeric], locale: Locale(identifier: "zh_Hant_TW@collation=stroke")) == .orderedAscending
        }
    }
    private var artists: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("歌手排序", selection: $artistSort) { ForEach(["歌曲數目", "名字筆畫", "喜好高低"], id: \.self) { Text($0) } }
            ForEach(groups, id: \.self) { name in
                let songs = model.tracks.filter { model.artist($0) == name }
                Button { expandedArtist = expandedArtist == name ? nil : name } label: {
                    HStack { ArtistAvatar(data: model.collection.artists.first { $0.name == name }?.avatar); Text(name); Spacer(); Text("\(songs.count) 首"); Image(systemName: expandedArtist == name ? "chevron.up" : "chevron.down") }
                }.buttonStyle(.plain).padding(12).background(OrcaTheme.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                if expandedArtist == name {
                    if let artist = model.collection.artists.first(where: { $0.name == name }) { ArtistEditor(model: model, artist: artist) }
                    ForEach(songs) { track in CollectionSongRow(model: model, track: track, queue: songs) }.padding(.leading, 12)
                }
            }
        }
    }
}

struct CollectionSongRow: View {
    @ObservedObject var model: PlayerModel
    let track: AudioTrack
    var queue: [AudioTrack] = []
    var playlistID = "all"
    @ViewState private var editing = false
    @ViewState private var deletion = false
    var body: some View {
        HStack(spacing: 10) {
            Button { model.recordSearch(); model.play(track, queue: queue.isEmpty ? model.tracks : queue) } label: {
                HStack { AlbumArtwork(variant: track.artwork, compact: true).frame(width: 42); VStack(alignment: .leading, spacing: 4) { Text(model.title(track)).lineLimit(1).foregroundStyle(model.selectedID == track.id ? OrcaTheme.cyan : OrcaTheme.text); Text(model.artist(track)).font(.caption).foregroundStyle(OrcaTheme.muted); if model.rating(track.id) > 0 { Text(String(repeating: "★", count: model.rating(track.id))).font(.caption).foregroundStyle(OrcaTheme.cyan) } }; Spacer() }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            FavoriteRatingButton(model: model, track: track)
            Menu {
                Button("編輯歌曲資料") { editing = true }
                Menu("加入播放清單") { ForEach(model.collection.playlists) { list in Button(list.name) { model.addToPlaylist(track.id, list.id) } }; if model.collection.playlists.isEmpty { Text("請先建立自訂清單") } }
                if model.collection.playlists.contains(where: { $0.id == playlistID }) { Button("從此播放清單移除") { model.removeFromPlaylist(track.id, playlistID) } }
                Button("刪除App內音樂檔案…", role: .destructive) { deletion = true }.disabled(track.isDemo)
            } label: { Image(systemName: "ellipsis.circle").frame(width: 32, height: 40) }.accessibilityLabel("管理 \(model.title(track))")
        }.padding(12).background(OrcaTheme.panel.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.selectedID == track.id ? OrcaTheme.cyan.opacity(0.5) : OrcaTheme.line.opacity(0.4)))
            .sheet(isPresented: $editing) { SongEditor(model: model, track: track) }
            .confirmationDialog("刪除「\(model.title(track))」的App內音檔？所有清單與歌曲音效綁定也會移除，外部原始檔保留。", isPresented: $deletion, titleVisibility: .visible) {
                Button("確認刪除音檔", role: .destructive) { Task { await model.deleteAudioFile(track) } }; Button("取消", role: .cancel) {}
            }
    }
}
struct FavoriteRatingButton: View {
    @ObservedObject var model: PlayerModel
    let track: AudioTrack
    @ViewState private var rating = false
    var body: some View {
        Image(systemName: model.favorites.contains(track.id) ? "heart.fill" : "heart")
            .foregroundStyle(OrcaTheme.cyan).frame(width: 40, height: 44).contentShape(Rectangle())
            .gesture(LongPressGesture(minimumDuration: 0.5).exclusively(before: TapGesture()).onEnded { value in
                switch value { case .first: rating = true; case .second: model.toggleFavorite(track) }
            })
            .accessibilityAddTraits(.isButton).accessibilityLabel("收藏與評分")
            .accessibilityAction { model.toggleFavorite(track) }.accessibilityAction(named: "評分") { rating = true }
            .contextMenu { Button("評分") { rating = true } }
            .confirmationDialog("歌曲評分", isPresented: $rating, titleVisibility: .visible) {
                ForEach(1...5, id: \.self) { stars in Button("\(stars) 顆星") { model.setRating(track.id, stars) } }
                Button("清除評分") { model.setRating(track.id, 0) }
            }
    }
}
struct SongEditor: View {
    @ObservedObject var model: PlayerModel
    let track: AudioTrack
    @Environment(\.dismiss) private var dismiss
    @ViewState private var title = ""
    @ViewState private var artist = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("編輯歌曲資料").font(.title2)
            TextField("歌名", text: $title).textFieldStyle(.roundedBorder)
            TextField("歌手／作者（可留白）", text: $artist).textFieldStyle(.roundedBorder)
            if !model.collection.artists.isEmpty { Menu("帶入已有歌手標籤") { ForEach(model.collection.artists) { item in Button(item.name) { artist = item.name } } } }
            Text("未知資料先由你填寫；不使用AI猜測。改名不改動原始音檔。").font(.caption).foregroundStyle(OrcaTheme.muted)
            HStack { Button("取消") { dismiss() }; Spacer(); Button("儲存") { model.editSong(track, title: title, artistName: artist); if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { dismiss() } }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 200 || artist.count > 100) }
        }.padding(24).frame(minWidth: 280).onAppear { title = model.title(track); artist = model.details(track.id).artistID == nil ? "" : model.artist(track) }
    }
}
struct ArtistAvatar: View {
    var data: Data?
    var body: some View {
        Group {
            #if os(iOS)
            if let data, let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFill() } else { Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(OrcaTheme.cyan) }
            #else
            if let data, let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFill() } else { Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(OrcaTheme.cyan) }
            #endif
        }.frame(width: 36, height: 36).clipShape(Circle())
    }
}
struct ArtistEditor: View {
    @ObservedObject var model: PlayerModel
    let artist: MusicArtist
    @ViewState private var name = ""
    @ViewState private var importer = false
    var body: some View {
        HStack {
            TextField("歌手名稱", text: $name).textFieldStyle(.roundedBorder)
            Button("改名") { model.updateArtist(artist.id, name: name, avatar: nil) }
            Button("頭貼") { importer = true }
        }.onAppear { name = artist.name }
        .fileImporter(isPresented: $importer, allowedContentTypes: [.image]) { result in
            do {
                let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 5_000_000 else { model.message = "頭貼請小於5 MB。"; return }
                let data = try Data(contentsOf: url)
                #if os(iOS)
                guard UIImage(data: data) != nil else { model.message = "無法解碼圖片。"; return }
                #else
                guard NSImage(data: data) != nil else { model.message = "無法解碼圖片。"; return }
                #endif
                model.updateArtist(artist.id, name: artist.name, avatar: data)
            } catch { model.message = error.localizedDescription }
        }
    }
}

struct MusicPlayerPage: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Menu { ForEach(model.modeOptions) { option in Button(option.name) { if model.useSongProfiles { model.bindSong(to: option.id) } else { model.applyPreset(id: option.id) } } } } label: { Label(model.presetName, systemImage: "slider.horizontal.3") }
                Spacer(); Text(model.rating(model.track.id) == 0 ? "未評分" : String(repeating: "★", count: model.rating(model.track.id))).foregroundStyle(OrcaTheme.cyan)
            }
            AlbumArtwork(variant: model.track.artwork).frame(maxWidth: 340)
            Text(model.title(model.track)).font(.title.bold()).multilineTextAlignment(.center)
            Text(model.artist(model.track)).foregroundStyle(OrcaTheme.muted)
            TransportControls(model: model)
            HStack {
                FavoriteRatingButton(model: model, track: model.track)
                Menu { ForEach(model.collection.playlists) { list in Button(list.name) { model.addToPlaylist(model.track.id, list.id) } }; if model.collection.playlists.isEmpty { Text("請先在首頁建立清單") } } label: { Label("加入清單", systemImage: "text.badge.plus") }
                Spacer(); Button { model.repeatOne.toggle() } label: { Image(systemName: "repeat.1").foregroundStyle(model.repeatOne ? OrcaTheme.cyan : OrcaTheme.muted) }.accessibilityLabel("單曲重複")
            }
            Picker("音效套用方式", selection: Binding(get: { model.useSongProfiles }, set: { model.setSongProfilePolicy($0) })) { Text("全部使用相同音效").tag(false); Text("依歌曲套用").tag(true) }.pickerStyle(.segmented)
            HStack { Button("細調等化器") { model.page = .equalizer }; Spacer(); SleepMenu(model: model) }
            OutputRouteRow()
        }.frame(maxWidth: 650).frame(maxWidth: .infinity)
    }
}
struct CompactMusicPlayer: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { model.page = .player } label: {
                    HStack { AlbumArtwork(variant: model.track.artwork, compact: true).frame(width: 38); VStack(alignment: .leading) { Text(model.title(model.track)).font(.subheadline).lineLimit(1); Text(model.artist(model.track)).font(.caption).foregroundStyle(OrcaTheme.muted).lineLimit(1) }; Spacer(minLength: 0) }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("展開正在播放")
                IconButton(symbol: model.isPlaying ? "pause.fill" : "play.fill", label: model.isPlaying ? "暫停" : "播放", active: true) { model.togglePlayback() }
                IconButton(symbol: "forward.end.fill", label: "下一首") { model.next() }
            }.padding(.horizontal, 14).padding(.vertical, 8)
            ProgressView(value: model.progress).tint(OrcaTheme.cyan).accessibilityLabel("歌曲進度")
        }.background(OrcaTheme.elevated)
    }
}
struct SleepMenu: View {
    @ObservedObject var model: PlayerModel
    @ViewState private var custom = false
    @ViewState private var bySongs = false
    @ViewState private var amount = 15
    var body: some View {
        Menu {
            Section("時間倒數（暫停也會繼續倒數）") { ForEach([5, 15, 30, 45, 60, 90, 120], id: \.self) { minutes in Button("\(minutes) 分鐘後暫停") { model.scheduleSleep(minutes: minutes) } } }
            Section("自然播完歌曲才計數，跳歌不扣除") { ForEach([1, 2, 3, 5, 10, 20], id: \.self) { songs in Button("播完 \(songs) 首後暫停") { model.scheduleSleep(songs: songs) } } }
            Button("自訂時間／歌曲數…") { custom = true }
            Button("取消定時") { model.cancelSleep() }
        } label: {
            if let date = model.sleepDeadline { Label("\(date.formatted(date: .omitted, time: .shortened)) 暫停", systemImage: "moon.zzz") }
            else if let left = model.sleepSongsRemaining { Label("剩 \(left) 首", systemImage: "moon.zzz") }
            else { Label("定時停止", systemImage: "moon.zzz") }
        }.sheet(isPresented: $custom) {
            VStack(alignment: .leading, spacing: 20) {
                Text("自訂聆聽限制").font(.title2)
                Picker("計算方式", selection: $bySongs) { Text("分鐘後暫停").tag(false); Text("播完歌曲後暫停").tag(true) }.pickerStyle(.segmented)
                Stepper("\(amount) \(bySongs ? "首" : "分鐘")", value: $amount, in: 1...240)
                HStack { Button("取消") { custom = false }; Spacer(); Button("開始") { if bySongs { model.scheduleSleep(songs: amount) } else { model.scheduleSleep(minutes: amount) }; custom = false } }
            }.padding(24).frame(minWidth: 280)
        }
    }
}
struct MusicSettingsView: View {
    @ObservedObject var model: PlayerModel
    @ViewState private var duplicates = false
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Panel(padding: 18) { VStack(alignment: .leading, spacing: 14) { Text("播放來源與輸出").font(.headline); Text("音樂來源：本機曲庫"); OutputRouteRow(); Text("藍牙車機／耳機是輸出裝置，請先在系統配對。此App不接收其他手機的藍牙音樂，也不控制其他播放器的EQ。").font(.caption).foregroundStyle(OrcaTheme.muted) } }
            Panel(padding: 18) { VStack(alignment: .leading, spacing: 14) { Text("聆聽限制").font(.headline); SleepMenu(model: model); Text("分鐘採時間倒數；歌曲數包含目前歌曲，僅自然播完才扣除，單曲重播也扣除。到期暫停、不刪歌；App重開後不恢復舊定時。").font(.caption).foregroundStyle(OrcaTheme.muted) } }
            Button("等化器與低音增強") { model.page = .equalizer }
            Button("開發日誌") { model.page = .developmentLog }
            Button("搜尋疑似重複歌曲") { duplicates = true }
            if duplicates {
                Text("相同內容已在匯入時去重。以下僅按歌名、歌手相同及時長差不超過2秒列候選，非聲紋或AI辨識；請人工檢查。").font(.caption).foregroundStyle(OrcaTheme.muted)
                let candidates = model.tracks.filter { a in model.tracks.contains { b in a.id != b.id && model.title(a).localizedCaseInsensitiveCompare(model.title(b)) == .orderedSame && model.artist(a) == model.artist(b) && abs(a.duration - b.duration) <= 2 } }
                if candidates.isEmpty { Text("未找到疑似重複歌曲") }
                ForEach(candidates) { CollectionSongRow(model: model, track: $0) }
            }
        }
    }
}
#if os(iOS)
struct SystemRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView { let view = AVRoutePickerView(); view.tintColor = .systemCyan; return view }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
#else
struct SystemRoutePicker: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView { AVRoutePickerView() }
    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}
#endif
struct OutputRouteRow: View {
    var body: some View { HStack { Label("系統音訊輸出", systemImage: "speaker.wave.2"); Spacer(); SystemRoutePicker().frame(width: 44, height: 38).accessibilityLabel("選擇系統音訊輸出") } }
}
