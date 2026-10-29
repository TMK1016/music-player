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
    private var selectedPlaylist: String? { get { navigation.selectedPlaylist } nonmutating set { navigation.selectedPlaylist = newValue } }
    private var selectedArtist: String? { get { navigation.selectedArtist } nonmutating set { navigation.selectedArtist = newValue } }
    @ViewState private var newArtist = false
    @ViewState private var artistName = ""
    var body: some View {
        Group {
        if let id = selectedPlaylist {
            LibraryDetailPage(model: model, title: model.playlistTitle(id), artwork: model.collection.playlistAppearance?[id]?.artwork, songs: model.songs(in: id), playlistID: id) { selectedPlaylist = nil }
        } else if let key = selectedArtist {
            let index = model.libraryIndex
            let artist = model.collection.artists.first { model.artistKey($0.name) == key }
            LibraryDetailPage(model: model, title: index.groups[key]?.name ?? artist?.name ?? "歌手", artwork: index.artists[key]?.avatar ?? artist?.avatar, songs: (index.groups[key]?.songIDs ?? []).compactMap { index.tracks[$0] }, playlistID: nil) { selectedArtist = nil }
        } else {
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
            if navigation.showsRankings {
            Divider()
            Text("排行榜").font(.title3.weight(.semibold))
            Picker("排行榜範圍", selection: Binding(get: { monthly }, set: { monthly = $0 })) { Text("當月").tag(true); Text("累計").tag(false) }.pickerStyle(.segmented).labelsHidden()
            rankingRows
            }
        }.padding(20).scrollTargetLayout() }
        .refreshable { if section == "播放清單" { navigation.allPlaylistsExpanded = true } }
        .scrollPosition(id: Binding(get: { navigation.scrollPositions[section] }, set: { value in
            navigation.recordScrollPosition(value, in: section)
        }))
        .onChange(of: section) { _, value in reader.scrollTo(navigation.scrollPositions[value] ?? "home-top", anchor: .top) }
        .onAppear { if let id = navigation.scrollPositions[section] { reader.scrollTo(id, anchor: .top) } }
        }
        }
        }
        .sheet(isPresented: $newArtist) {
            VStack(spacing: 20) {
                Text("新增歌手").font(.title2)
                TextField("歌手名稱", text: $artistName).textFieldStyle(.roundedBorder)
                HStack { Button("取消") { newArtist = false }; Spacer(); Button("新增") {
                    let value = artistName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty, value.count <= 100 else { return }
                    if !model.collection.artists.contains(where: { $0.name.localizedCaseInsensitiveCompare(value) == .orderedSame }), !groups.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) {
                        model.collection.artists.append(MusicArtist(name: value))
                    }
                    newArtist = false
                } }
            }.padding(24).frame(minWidth: 300).presentationBackground(OrcaTheme.sheet)
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
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 20) {
            ForEach(navigation.allPlaylistsExpanded ? model.visiblePlaylistIDs : Array(model.visiblePlaylistIDs.prefix(3)), id: \.self) { id in
                Button { selectedPlaylist = id } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geo in
                            DecodedArtwork(data: model.collection.playlistAppearance?[id]?.artwork, symbol: id == "favorites" ? "heart.fill" : "music.note.list")
                                .frame(width: geo.size.width, height: geo.size.height).clipped()
                        }.aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 18))
                        Text(model.playlistTitle(id)).foregroundStyle(id.hasPrefix("stars") ? OrcaTheme.star : .white).lineLimit(1)
                        Text("\(model.libraryIndex.playlistIDs[id]?.count ?? 0) 首歌曲").font(.caption).foregroundStyle(OrcaTheme.muted)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).id("playlist-header:" + id)
                .accessibilityLabel("開啟播放清單：\(model.playlistTitle(id))")
                .contextMenu {
                    Button("編輯清單照片與名稱") { editingPlaylist = id }
                    Button("編輯清單歌曲") { editingSongs = id }
                    Button("往前移") { movePlaylist(id, by: -1) }
                    Button("往後移") { movePlaylist(id, by: 1) }
                    Button("隱藏清單") { model.hidePlaylist(id, hidden: true) }
                    if !model.isSystemPlaylist(id) { Button("刪除清單", role: .destructive) { deletingPlaylist = id } }
                }
                .onDrag { draggedPlaylist = id; return NSItemProvider(object: id as NSString) }
                .onDrop(of: [.text], delegate: LibraryReorderDrop(target: id, dragged: $draggedPlaylist) { source, target in model.movePlaylist(source, to: target) })
            }
            Button { name = ""; listError = nil; newList = true } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "plus").font(.largeTitle).frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    Text("新增播放清單").font(.subheadline)
                }.foregroundStyle(.white).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if model.visiblePlaylistIDs.count > 3 {
                Button(navigation.allPlaylistsExpanded ? "收合播放清單" : "顯示全部播放清單") { navigation.allPlaylistsExpanded.toggle() }.buttonStyle(.plain).frame(minHeight: 44)
            }
            if !(model.collection.hiddenPlaylists ?? []).isEmpty {
                Button { hiddenLists = true } label: { Label("管理隱藏清單", systemImage: "eye.slash").frame(minHeight: 44) }.buttonStyle(.plain)
            }
        }.scrollTargetLayout()
    }
    @ViewBuilder private var allSongRows: some View {
        let songs = model.sortedSongs
            HStack {
                Text("\(songs.count) 首歌曲").font(.caption).foregroundStyle(OrcaTheme.muted)
                Spacer()
                Button { sortingSongs = true } label: { Label(model.collection.effectiveSongSort, systemImage: model.collection.isSongSortAscending ? "arrow.up" : "arrow.down").font(.subheadline).frame(minHeight: 44) }.buttonStyle(.plain)
                    .accessibilityLabel("全部歌曲排序")
                    .popover(isPresented: $sortingSongs, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                        VStack(spacing: 4) { ForEach(SongSortMode.allCases, id: \.self) { option in
                            Button { model.selectSongSort(option); sortingSongs = false } label: {
                                HStack { Text(option.rawValue); Spacer(); if model.collection.effectiveSongSort == option.rawValue { Image(systemName: model.collection.isSongSortAscending ? "arrow.up" : "arrow.down") } }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        } }.padding(12).frame(width: 180).foregroundStyle(.white).presentationCompactAdaptation(.popover).presentationBackground(OrcaTheme.sheet)
                    }
            }
            ForEach(songs) { song in
                CollectionSongRow(model: model, track: song, queue: songs).id("all-song:" + song.id)
                    .contextMenu {
                        Button("往上移") { moveSong(song.id, by: -1) }.disabled(songs.first?.id == song.id)
                        Button("往下移") { moveSong(song.id, by: 1) }.disabled(songs.last?.id == song.id)
                    }
                    .onDrag { draggedSong = song.id; return NSItemProvider(object: song.id as NSString) }
                    .onDrop(of: [.text], delegate: LibraryReorderDrop(target: song.id, dragged: $draggedSong) { source, target in model.moveSong(source, to: target) })
            }

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
        let names = (index.groupOrders[artistSort] ?? []).compactMap { index.groups[$0]?.name }
        return names + model.collection.artists.map(\.name).filter { !names.contains($0) }
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
            ForEach(groups, id: \.self) { name in
                let key = model.artistKey(name)
                Button { selectedArtist = key } label: {
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            DecodedArtwork(data: model.libraryIndex.artists[key]?.avatar ?? model.collection.artists.first(where: { $0.name == name })?.avatar, symbol: "person.fill")
                                .frame(width: geo.size.width, height: geo.size.height).clipShape(Circle())
                        }.aspectRatio(1, contentMode: .fit)
                        Text(name).font(.caption).foregroundStyle(.white).lineLimit(1)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain).id("artist-header:" + key).accessibilityLabel("開啟歌手：\(name)")
                .contextMenu {
                    Button("編輯資料") { editingArtist = model.collection.artists.first { $0.name == name } ?? MusicArtist(id: "native:" + name, name: name) }
                    Button("往前移") { moveArtist(key, by: -1) }
                    Button("往後移") { moveArtist(key, by: 1) }
                }
                .onDrag { draggedArtist = key; return NSItemProvider(object: key as NSString) }
                .onDrop(of: [.text], delegate: LibraryReorderDrop(target: key, dragged: $draggedArtist) { source, target in
                    model.moveArtist(source, to: target, in: groups.map { model.artistKey($0) }); model.collection.artistSort = "自訂順序"
                })
            }
            Button { artistName = ""; newArtist = true } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus").font(.largeTitle).frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit).background(.white.opacity(0.15), in: Circle())
                    Text("新增歌手").font(.caption)
                }.foregroundStyle(.white).contentShape(Rectangle())
            }.buttonStyle(.plain)
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
                        HStack(spacing: 10) {
                            SongArtwork(model: model, track: song, compact: true).frame(width: 38, height: 38)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(model.title(song)).lineLimit(1).foregroundStyle(.white)
                                Text(model.artist(song)).font(.caption).foregroundStyle(OrcaTheme.muted).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.horizontal, 8).background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 12)).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    Text("\(model.playCount(song.id, monthly: monthly))").font(.caption.monospacedDigit()).frame(minWidth: 36)
                }.id("ranking:" + (monthly ? "month:" : "all:") + song.id)
            }
        }.scrollTargetLayout()
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


private struct LibraryDetailPage: View {
    @ObservedObject var model: PlayerModel
    let title: String
    let artwork: Data?
    let songs: [AudioTrack]
    let playlistID: String?
    let back: () -> Void
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Button(action: back) { Label("返回曲庫", systemImage: "chevron.left").frame(minHeight: 44).contentShape(Rectangle()) }.buttonStyle(.plain)
                DecodedArtwork(data: artwork ?? songs.first.flatMap { model.coverData($0) }, symbol: playlistID == nil ? "person.fill" : "music.note.list")
                    .frame(width: 220, height: 220).clipShape(RoundedRectangle(cornerRadius: 20)).frame(maxWidth: .infinity)
                Text(title).font(.title.bold())
                HStack {
                    Text("\(songs.count) 首歌曲").foregroundStyle(OrcaTheme.muted)
                    Spacer()
                    Button { if let first = songs.first { model.play(first, queue: songs, contextName: title, playlistID: playlistID) } } label: {
                        Label("播放全部", systemImage: "play.fill").foregroundStyle(.black).padding(12).background(.green, in: Capsule())
                    }.buttonStyle(.plain).disabled(songs.isEmpty)
                }
                ForEach(songs) { song in
                    CollectionSongRow(model: model, track: song, queue: songs, playlistID: playlistID ?? "all", queueName: title)
                }
            }.padding(20)
        }.background {
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    OrcaTheme.background
                    if let data = artwork ?? songs.first.flatMap({ model.coverData($0) }) {
                        DecodedArtwork(data: data, maxPixelSize: 128).frame(width: geo.size.width, height: 350).clipped().blur(radius: 30).opacity(0.5)
                    } else { OrcaTheme.blue.opacity(0.25).frame(height: 350) }
                    LinearGradient(colors: [.clear, OrcaTheme.background], startPoint: .top, endPoint: .bottom).frame(height: 380)
                }.clipped()
            }.allowsHitTesting(false)
        }
    }
}
