import SwiftUI
import UniformTypeIdentifiers

struct MusicHomeView: View {
    @ObservedObject var model: PlayerModel
    @ObservedObject var navigation: HomeLibraryState
    init(model: PlayerModel) { self.model = model; self.navigation = model.homeState }
    private var section: String { get { navigation.section } nonmutating set { navigation.section = newValue } }
    private var expandedPlaylist: String? { get { navigation.expandedPlaylist } nonmutating set { navigation.expandedPlaylist = newValue } }
    private var expandedArtist: String? { get { navigation.expandedArtist } nonmutating set { navigation.expandedArtist = newValue } }
    private var artistSort: String { model.collection.artistSort ?? ((model.collection.artistOrder ?? []).isEmpty ? "歌曲數目" : "自訂順序") }
    private var monthly: Bool { get { navigation.monthly } nonmutating set { navigation.monthly = newValue } }
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
    @ViewState private var draggedSong: String?
    @ViewState private var sortingSongs = false
    var body: some View {
        ScrollViewReader { reader in
        ScrollView { LazyVStack(alignment: .leading, spacing: 18) {
            if !model.importSummary.isEmpty { Text(model.importSummary).font(.caption).foregroundStyle(OrcaTheme.cyan) }
            Picker("曲庫", selection: Binding(get: { section }, set: { section = $0 })) {
                ForEach(["播放清單", "歌手列表", "全部歌曲"], id: \.self) { Text($0) }
            }.pickerStyle(.segmented).labelsHidden().id("home-top")
            if section == "播放清單" { playlistRows }
            else if section == "歌手列表" { artistRows }
            else {
                allSongRows

            }
            Divider()
            Text("排行榜").font(.title3.weight(.semibold))
            Picker("排行榜範圍", selection: Binding(get: { monthly }, set: { monthly = $0 })) { Text("當月").tag(true); Text("累計").tag(false) }.pickerStyle(.segmented).labelsHidden()
            rankingRows
        }.padding(20).scrollTargetLayout() }
        .scrollPosition(id: Binding(get: { navigation.scrollPositions[section] }, set: { value in
            guard let value else { return }
            let prefix = section == "全部歌曲" ? "all-song:" : section == "歌手列表" ? "artist-header:" : "playlist-header:"
            if value == "home-top" || value.hasPrefix(prefix) { navigation.scrollPositions[section] = value }
        }))
        .onChange(of: section) { _, value in reader.scrollTo(navigation.scrollPositions[value] ?? "home-top", anchor: .top) }
        .onAppear { if let id = navigation.scrollPositions[section] { reader.scrollTo(id, anchor: .top) } }
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
        LazyVStack(alignment: .leading, spacing: 12) {
            if model.visiblePlaylistIDs.isEmpty { Text("匯入、收藏或評分後，對應清單會出現在這裡。也可以建立自己的清單。").font(.subheadline).foregroundStyle(OrcaTheme.muted) }
            ForEach(model.visiblePlaylistIDs, id: \.self) { id in
                HStack(spacing: 0) {
                    Button { expandedPlaylist = expandedPlaylist == id ? nil : id } label: {
                        HStack(spacing: 14) {
                            LibraryArtwork(data: model.collection.playlistAppearance?[id]?.artwork, symbol: id == "favorites" ? "heart.fill" : "music.note.list")
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.playlistTitle(id)).foregroundStyle(id.hasPrefix("stars") ? OrcaTheme.star : .white).lineLimit(1)
                                Text("\(model.libraryIndex.playlistIDs[id]?.count ?? 0) 首歌曲").font(.caption).foregroundStyle(OrcaTheme.muted)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: expandedPlaylist == id ? "chevron.up" : "chevron.down").foregroundStyle(OrcaTheme.muted)
                        }.padding(.vertical, 8).padding(.leading, 8).padding(.trailing, 4)
                            .frame(maxWidth: .infinity, minHeight: 72).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("\(model.playlistTitle(id))，\(expandedPlaylist == id ? "收合" : "展開")")
                }
                .background(expandedPlaylist == id ? OrcaTheme.blue.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
                .selectionOutline(expandedPlaylist == id).id("playlist-header:" + id)
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
                    let works = model.songs(in: id)
                    LazyVStack(spacing: 12) { ForEach(works) { song in
                        CollectionSongRow(model: model, track: song, queue: works, playlistID: id, queueName: model.playlistTitle(id)).id("playlist:" + id + ":" + song.id)
                    } }.id("playlist-songs:" + id)
                }
            }
            Button { name = ""; listError = nil; newList = true } label: { Label("新增播放清單", systemImage: "plus.circle").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.buttonStyle(.plain)
            if !(model.collection.hiddenPlaylists ?? []).isEmpty {
                Button { hiddenLists = true } label: { Label("管理隱藏清單", systemImage: "eye.slash").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.buttonStyle(.plain)
            }
        }.scrollTargetLayout()
    }
    private var allSongRows: some View {
        let songs = model.sortedSongs
        return LazyVStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(songs.count) 首歌曲").font(.caption).foregroundStyle(OrcaTheme.muted)
                Spacer()
                Button { sortingSongs = true } label: { Label(model.collection.songSort ?? "自訂順序", systemImage: "arrow.up.arrow.down").font(.subheadline).frame(minHeight: 44) }.buttonStyle(.plain)
                    .accessibilityLabel("全部歌曲排序")
                    .popover(isPresented: $sortingSongs, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                        VStack(spacing: 4) { ForEach(["自訂順序", "歌名", "歌手", "最近新增"], id: \.self) { option in
                            Button { model.collection.songSort = option; sortingSongs = false } label: {
                                HStack { Text(option); Spacer(); if (model.collection.songSort ?? "自訂順序") == option { Image(systemName: "checkmark") } }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        } }.padding(12).frame(width: 180).foregroundStyle(.white).presentationCompactAdaptation(.popover).presentationBackground(OrcaTheme.sheet)
                    }
            }
            ForEach(Array(songs.prefix(navigation.limit))) { song in
                CollectionSongRow(model: model, track: song, queue: songs).id("all-song:" + song.id)
                    .contextMenu {
                        Button("往上移") { moveSong(song.id, by: -1) }.disabled(songs.first?.id == song.id)
                        Button("往下移") { moveSong(song.id, by: 1) }.disabled(songs.last?.id == song.id)
                    }
                    .onDrag { draggedSong = song.id; return NSItemProvider(object: song.id as NSString) }
                    .onDrop(of: [.text], delegate: LibraryReorderDrop(target: song.id, dragged: $draggedSong) { source, target in model.moveSong(source, to: target) })
            }
            if navigation.limit < songs.count {
                Button("載入更多50首 · 已顯示\(min(navigation.limit, songs.count))／\(songs.count)") { navigation.limit += 50 }.frame(maxWidth: .infinity, minHeight: 44)
            }
        }.scrollTargetLayout()
    }
    private func moveSong(_ id: String, by offset: Int) {
        let ids = model.sortedSongs.map(\.id)
        guard let index = ids.firstIndex(of: id), ids.indices.contains(index + offset) else { return }
        model.moveSong(id, to: ids[index + offset])
    }
    private func movePlaylist(_ id: String, by offset: Int) {
        let ids = model.visiblePlaylistIDs
        guard let i = ids.firstIndex(of: id), ids.indices.contains(i + offset) else { return }
        model.movePlaylist(id, to: ids[i + offset])
    }
    private var groups: [String] {
        let index = model.libraryIndex
        return (index.groupOrders[artistSort] ?? []).compactMap { index.groups[$0]?.name }
    }
    private var artistRows: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
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
                let index = model.libraryIndex
                let songs = (index.groups[key]?.songIDs ?? []).compactMap { index.tracks[$0] }
                Button { expandedArtist = expandedArtist == key ? nil : key } label: {
                    HStack(spacing: 12) {
                        ArtistAvatar(data: model.libraryIndex.artists[key]?.avatar, size: 68)
                        VStack(alignment: .leading, spacing: 5) { Text(name).font(.title3).foregroundStyle(.white).lineLimit(1); Text("歌手 · \(songs.count) 首歌曲").font(.caption).foregroundStyle(OrcaTheme.muted) }
                        Spacer()
                        Image(systemName: expandedArtist == key ? "chevron.up" : "chevron.down")
                    }.padding(12).frame(maxWidth: .infinity, minHeight: 64).contentShape(Rectangle())
                }.buttonStyle(.plain).background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 12)).selectionOutline(expandedArtist == key).id("artist-header:" + key)
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
        }.scrollTargetLayout()
    }
    private func moveArtist(_ id: String, by offset: Int) {
        let ids = groups.map { model.artistKey($0) }
        guard let i = ids.firstIndex(of: id), ids.indices.contains(i + offset) else { return }
        model.moveArtist(id, to: ids[i + offset], in: ids); model.collection.artistSort = "自訂順序"
    }
    private var rankingRows: some View {
        let index = model.libraryIndex
        let ranked = (monthly ? index.monthlyRanking : index.totalRanking).compactMap { index.tracks[$0] }
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

extension View {
    func selectionOutline(_ selected: Bool) -> some View {
        overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(selected ? 0.9 : 0), lineWidth: 1.5)
            .shadow(color: .white.opacity(selected ? 0.4 : 0), radius: 4))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
