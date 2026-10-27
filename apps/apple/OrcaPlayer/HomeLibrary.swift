import SwiftUI
import UniformTypeIdentifiers

struct MusicHomeView: View {
    @ObservedObject var model: PlayerModel
    @ViewState private var section = "播放清單"
    @ViewState private var expandedPlaylist: String?
    @ViewState private var expandedArtist: String?
    private var artistSort: String { model.collection.artistSort ?? ((model.collection.artistOrder ?? []).isEmpty ? "歌曲數目" : "自訂順序") }
    @ViewState private var monthly = true
    @ViewState private var newList = false
    @ViewState private var name = ""
    @ViewState private var listError: String?
    @ViewState private var editingPlaylist: String?
    @ViewState private var editingSongs: String?
    @ViewState private var deletingPlaylist: String?
    @ViewState private var editingArtist: MusicArtist?
    @ViewState private var draggedPlaylist: String?
    @ViewState private var draggedArtist: String?
    @ViewState private var hiddenLists = false
    @ViewState private var sortingArtists = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !model.importSummary.isEmpty { Text(model.importSummary).font(.caption).foregroundStyle(OrcaTheme.cyan) }
            Picker("曲庫", selection: $section) {
                ForEach(["播放清單", "歌手列表", "全部歌曲"], id: \.self) { Text($0) }
            }.pickerStyle(.segmented).labelsHidden()
            if section == "播放清單" { playlistRows }
            else if section == "歌手列表" { artistRows }
            else {
                LazyVStack(spacing: 12) { ForEach(model.tracks) { CollectionSongRow(model: model, track: $0, queue: model.tracks).id("all-song:" + $0.id) } }.id("all-songs-section")
            }
            Divider()
            Text("排行榜").font(.title3.weight(.semibold))
            Picker("排行榜範圍", selection: $monthly) { Text("當月").tag(true); Text("累計").tag(false) }.pickerStyle(.segmented).labelsHidden()
            rankingRows
        }
        .sheet(isPresented: $newList) { newPlaylist }
        .sheet(isPresented: Binding(get: { editingPlaylist != nil }, set: { if !$0 { editingPlaylist = nil } })) {
            if let id = editingPlaylist { PlaylistDetailsEditor(model: model, playlistID: id) }
        }
        .sheet(isPresented: Binding(get: { editingSongs != nil }, set: { if !$0 { editingSongs = nil } })) {
            if let id = editingSongs { PlaylistSongsEditor(model: model, playlistID: id) }
        }
        .sheet(item: $editingArtist) { ArtistDetailsEditor(model: model, artist: $0) }
        .sheet(isPresented: $hiddenLists) { HiddenPlaylistsEditor(model: model) }
        .confirmationDialog("刪除播放清單？歌曲檔案會保留。", isPresented: Binding(get: { deletingPlaylist != nil }, set: { if !$0 { deletingPlaylist = nil } }), titleVisibility: .visible) {
            Button("刪除清單", role: .destructive) { if let id = deletingPlaylist { model.deletePlaylist(id) }; deletingPlaylist = nil }
        }
    }
    private var playlistRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.visiblePlaylistIDs.isEmpty { Text("匯入、收藏或評分後，對應清單會出現在這裡。也可以建立自己的清單。").font(.subheadline).foregroundStyle(OrcaTheme.muted) }
            ForEach(model.visiblePlaylistIDs, id: \.self) { id in
                HStack(spacing: 0) {
                    Button { expandedPlaylist = expandedPlaylist == id ? nil : id } label: {
                        HStack(spacing: 14) {
                            LibraryArtwork(data: model.collection.playlistAppearance?[id]?.artwork, symbol: id == "favorites" ? "heart.fill" : "music.note.list")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.playlistTitle(id)).foregroundStyle(id.hasPrefix("stars") ? OrcaTheme.star : .white).lineLimit(1)
                                Text("\(model.songs(in: id).count) 首歌曲").font(.caption).foregroundStyle(OrcaTheme.muted)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: expandedPlaylist == id ? "chevron.up" : "chevron.down").foregroundStyle(OrcaTheme.muted)
                        }.padding(.vertical, 8).padding(.leading, 8).padding(.trailing, 4)
                            .frame(maxWidth: .infinity, minHeight: 72).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("\(model.playlistTitle(id))，\(expandedPlaylist == id ? "收合" : "展開")")
                }
                .background(expandedPlaylist == id ? OrcaTheme.blue.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
                .contextMenu {
                    Button("編輯清單照片與名稱") { editingPlaylist = id }
                    Button("編輯清單歌曲") { editingSongs = id }
                    Button("往上移") { movePlaylist(id, by: -1) }.disabled(model.visiblePlaylistIDs.first == id)
                    Button("往下移") { movePlaylist(id, by: 1) }.disabled(model.visiblePlaylistIDs.last == id)
                    Button("隱藏清單") { model.hidePlaylist(id, hidden: true) }
                    if !model.isSystemPlaylist(id) { Button("刪除清單", role: .destructive) { deletingPlaylist = id } }
                }
                .onDrag { draggedPlaylist = id; return NSItemProvider(object: id as NSString) }
                .onDrop(of: [.text], delegate: LibraryReorderDrop(target: id, dragged: $draggedPlaylist) { source, target in model.movePlaylist(source, to: target) })
                .accessibilityHint("點擊整列展開或收合；長按編輯或上下拖曳排序")
                if expandedPlaylist == id {
                    LazyVStack(spacing: 12) { ForEach(model.songs(in: id)) { song in
                        CollectionSongRow(model: model, track: song, queue: model.songs(in: id), playlistID: id, queueName: model.playlistTitle(id)).id("playlist:" + id + ":" + song.id)
                    } }.id("playlist-songs:" + id)
                }
            }
            Button { name = ""; listError = nil; newList = true } label: { Label("新增播放清單", systemImage: "plus.circle").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.buttonStyle(.plain)
            if !(model.collection.hiddenPlaylists ?? []).isEmpty {
                Button { hiddenLists = true } label: { Label("管理隱藏清單", systemImage: "eye.slash").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.buttonStyle(.plain)
            }
        }
    }
    private func movePlaylist(_ id: String, by offset: Int) {
        let ids = model.visiblePlaylistIDs
        guard let i = ids.firstIndex(of: id), ids.indices.contains(i + offset) else { return }
        model.movePlaylist(id, to: ids[i + offset])
    }
    private var groups: [String] {
        let names = Set(model.tracks.map { model.artist($0) })
        return names.sorted { a, b in
            if artistSort == "自訂順序" {
                let order = model.collection.artistOrder ?? []
                let x = order.firstIndex(of: model.artistKey(a)) ?? Int.max, y = order.firstIndex(of: model.artistKey(b)) ?? Int.max
                if x != y { return x < y }
            }
            let left = model.tracks.filter { model.artist($0) == a }, right = model.tracks.filter { model.artist($0) == b }
            if artistSort == "歌曲數目", left.count != right.count { return left.count > right.count }
            if artistSort == "喜好高低" {
                @MainActor func mean(_ songs: [AudioTrack]) -> Double { let values = songs.map { model.rating($0.id) }.filter { $0 > 0 }; return values.isEmpty ? 0 : Double(values.reduce(0,+)) / Double(values.count) }
                let x = mean(left), y = mean(right); if x != y { return x > y }
            }
            return a.compare(b, options: [.numeric], locale: Locale(identifier: "zh_Hant_TW@collation=stroke")) == .orderedAscending
        }
    }
    private var artistRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Button { sortingArtists = true } label: {
                    Label(artistSort, systemImage: "arrow.up.arrow.down").font(.subheadline).foregroundStyle(.white).frame(minHeight: 44).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("歌手排序：\(artistSort)")
                    .popover(isPresented: $sortingArtists, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(["歌曲數目", "名字筆畫", "喜好高低", "自訂順序"], id: \.self) { value in
                                Button { model.collection.artistSort = value; sortingArtists = false } label: {
                                    HStack { Text(value); Spacer(); if artistSort == value { Image(systemName: "checkmark") } }
                                        .font(.subheadline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }
                        }.padding(12).frame(width: 180).presentationCompactAdaptation(.popover).presentationBackground(OrcaTheme.sheet)
                    }
            }
            ForEach(groups, id: \.self) { name in
                let key = model.artistKey(name)
                let songs = model.tracks.filter { model.artist($0) == name }
                Button { expandedArtist = expandedArtist == key ? nil : key } label: {
                    HStack(spacing: 12) {
                        ArtistAvatar(data: model.collection.artists.first { $0.name == name }?.avatar)
                        Text(name).foregroundStyle(.white).lineLimit(1)
                        Spacer(); Text("\(songs.count) 首").foregroundStyle(OrcaTheme.muted)
                        Image(systemName: expandedArtist == key ? "chevron.up" : "chevron.down")
                    }.padding(12).frame(maxWidth: .infinity, minHeight: 64).contentShape(Rectangle())
                }.buttonStyle(.plain).background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                    .contextMenu {
                        Button("編輯資料") { editingArtist = model.collection.artists.first { $0.name == name } ?? MusicArtist(id: "native:" + name, name: name) }
                        Button("往上移") { moveArtist(key, by: -1) }.disabled(groups.first.map { model.artistKey($0) } == key)
                        Button("往下移") { moveArtist(key, by: 1) }.disabled(groups.last.map { model.artistKey($0) } == key)
                    }
                    .onDrag { draggedArtist = key; return NSItemProvider(object: key as NSString) }
                    .onDrop(of: [.text], delegate: LibraryReorderDrop(target: key, dragged: $draggedArtist) { source, target in
                        model.moveArtist(source, to: target, in: groups.map { model.artistKey($0) }); model.collection.artistSort = "自訂順序"
                    })
                if expandedArtist == key {
                    LazyVStack(spacing: 12) { ForEach(songs) { CollectionSongRow(model: model, track: $0, queue: songs, queueName: name).id("artist:" + key + ":" + $0.id) } }.id("artist-songs:" + key).padding(.leading, 8)
                }
            }
        }
    }
    private func moveArtist(_ id: String, by offset: Int) {
        let ids = groups.map { model.artistKey($0) }
        guard let i = ids.firstIndex(of: id), ids.indices.contains(i + offset) else { return }
        model.moveArtist(id, to: ids[i + offset], in: ids); model.collection.artistSort = "自訂順序"
    }
    private var rankingRows: some View {
        let ranked = model.tracks.filter { model.playCount($0.id, monthly: monthly) > 0 }.sorted {
            let a = model.playCount($0.id, monthly: monthly), b = model.playCount($1.id, monthly: monthly)
            return a == b ? model.title($0) < model.title($1) : a > b
        }
        return VStack(alignment: .leading, spacing: 12) {
            if ranked.isEmpty { Text("尚無達標播放紀錄").foregroundStyle(OrcaTheme.muted) }
            ForEach(Array(ranked.prefix(10).enumerated()), id: \.element.id) { index, song in
                HStack(spacing: 10) {
                    Text("\(index + 1)").monospacedDigit().frame(width: 24)
                    Button { model.play(song, queue: ranked, contextName: monthly ? "當月排行榜" : "累計排行榜") } label: {
                        Text(model.title(song)).lineLimit(1).foregroundStyle(OrcaTheme.text).frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.horizontal, 12).background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 12)).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Text("\(model.playCount(song.id, monthly: monthly))次").font(.caption.monospacedDigit()).frame(minWidth: 36)
                }.id("ranking:" + (monthly ? "month:" : "all:") + song.id)
            }
        }
    }
    private var newPlaylist: some View {
        VStack(spacing: 20) {
            Text("新增播放清單").font(.title2)
            TextField("清單名稱", text: $name).textFieldStyle(.roundedBorder)
            if let listError { Text(listError).font(.caption).foregroundStyle(.orange) }
            HStack {
                Button("取消") { newList = false }.frame(minHeight: 44)
                Spacer()
                Button("建立") {
                    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty, title.count <= 60 else { listError = "名稱須為1～60字。"; return }
                    guard !(PlayerModel.systemPlaylistIDs + model.collection.playlists.map(\.id)).contains(where: { model.playlistTitle($0).localizedCaseInsensitiveCompare(title) == .orderedSame }) else { listError = "已有相同名稱。"; return }
                    model.createPlaylist(title); newList = false
                }.frame(minHeight: 44)
            }
        }.padding(24).frame(minWidth: 280).themedSheet()
    }
}

struct LibraryReorderDrop: DropDelegate {
    let target: String
    @Binding var dragged: String?
    let move: (String, String) -> Void
    func dropEntered(info: DropInfo) { if let id = dragged, id != target { move(id, target) } }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { dragged = nil; return true }
}
