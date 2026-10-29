import SwiftUI
import UniformTypeIdentifiers

struct MusicHomeView: View {
    @ObservedObject var model: PlayerModel
    @ObservedObject var navigation: HomeLibraryState
    init(model: PlayerModel) { self.model = model; self.navigation = model.homeState }
    private var section: String { get { navigation.section } nonmutating set { navigation.section = newValue } }
    private var artistSort: String { model.collection.artistSort ?? ((model.collection.artistOrder ?? []).isEmpty ? "歌曲數目" : "自訂順序") }
    private var monthly: Bool { get { navigation.monthly } nonmutating set { navigation.monthly = newValue } }
    @ViewState private var newList = false
    @ViewState private var editingPlaylist: String?
    @ViewState private var editingSongs: String?
    @ViewState private var deletingPlaylist: String?
    @ViewState private var editingArtist: MusicArtist?
    @ViewState private var draggedPlaylist: String?
    @ViewState private var draggedArtist: String?
    @ViewState private var hiddenLists = false
    @ViewState private var sortingArtists = false
    @ViewState private var sortingPlaylists = false
    @ViewState private var draggedSong: String?
    @ViewState private var sortingSongs = false
    private var selectedPlaylist: String? { get { navigation.selectedPlaylist } nonmutating set { navigation.selectedPlaylist = newValue } }
    private var selectedArtist: String? { get { navigation.selectedArtist } nonmutating set { navigation.selectedArtist = newValue } }
    @ViewState private var newArtist = false
    var body: some View {
        Group {
        if selectedPlaylist != nil {
            LibraryDetailPage(model: model, ids: model.visiblePlaylistIDs, artist: false)
        } else if selectedArtist != nil {
            LibraryDetailPage(model: model, ids: groups.map { model.artistKey($0) }, artist: true)
        } else {
        VStack(spacing: 0) {
            Picker("曲庫", selection: Binding(get: { section }, set: { section = $0 })) {
                ForEach(["播放清單", "歌手列表", "全部歌曲"], id: \.self) { Text($0) }
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 20).frame(height: 56)
            libraryInfoRow.frame(height: 44).padding(.horizontal, 20).padding(.bottom, 8)
        GeometryReader { viewport in
        ScrollViewReader { reader in
        ScrollView(.vertical) { LazyVStack(alignment: .leading, spacing: 12) {
            if !model.importSummary.isEmpty { Text(model.importSummary).font(.caption).foregroundStyle(OrcaTheme.cyan) }
            Color.clear.frame(maxWidth: .infinity).frame(height: 0).id("home-top")
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
        }.frame(width: max(0, viewport.size.width - 40), alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20).scrollTargetLayout() }
        .frame(width: viewport.size.width)
        .modifier(HomeScrollActivity(navigation: navigation))
        .simultaneousGesture(DragGesture(minimumDistance: 12)
            .onChanged { _ in navigation.noteContentDrag() }
            .onEnded { value in
                navigation.noteContentDrag()
                guard draggedPlaylist == nil, draggedArtist == nil, draggedSong == nil else { return }
                navigation.handleSwipe(horizontal: value.translation.width, vertical: value.translation.height)
            })
        .scrollPosition(id: Binding(get: { navigation.scrollPositions[section] }, set: { value in
            navigation.recordScrollPosition(value, in: section)
        }), anchor: .topLeading)
        .onChange(of: section) { _, value in reader.scrollTo(navigation.scrollPositions[value] ?? "home-top", anchor: .topLeading) }
        .task(id: section) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            reader.scrollTo(navigation.scrollPositions[section] ?? "home-top", anchor: .topLeading)
        }
        }
        }
        }
        }
        }
        .sheet(isPresented: $newArtist) {
            EntityDetailsForm(title: "新增歌手", placeholder: "歌手名稱", circular: true) { name, artwork in
                let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty, clean.count <= 100, !groups.contains(where: { $0.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return "名稱須為1～100字，且不可與其他歌手重複。" }
                guard artwork == nil || artwork!.count <= 5_000_000 else { return "圖片須小於5 MB。" }
                model.collection.artists.append(MusicArtist(name: clean, avatar: artwork))
                return nil
            }
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
    @ViewBuilder private var libraryInfoRow: some View {
        if section == "全部歌曲" { songInfoRow }
        else if section == "歌手列表" { artistInfoRow }
        else {
            HStack {
                Text("\(model.visiblePlaylistIDs.count) 個清單").font(.caption).foregroundStyle(OrcaTheme.muted)
                Spacer()
                Button { if navigation.canActivateContent() { sortingPlaylists = true } } label: {
                    Image(systemName: "arrow.up.arrow.down").font(.subheadline).frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("播放清單排序").accessibilityValue(model.collection.playlistSort ?? "自訂順序")
                .popover(isPresented: $sortingPlaylists, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    VStack(spacing: 4) {
                        ForEach(["自訂順序", "名稱筆畫", "歌曲數目"], id: \.self) { value in
                            Button { model.selectPlaylistSort(value); sortingPlaylists = false } label: {
                                HStack { Text(value); Spacer(); if (model.collection.playlistSort ?? "自訂順序") == value { Image(systemName: "checkmark") } }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }.padding(12).frame(width: 180).foregroundStyle(.white).presentationCompactAdaptation(.popover).presentationBackground(OrcaTheme.sheet)
                }
            }
        }
    }
    private var songInfoRow: some View {
        let songs = model.sortedSongs
        return HStack {
                Text("\(songs.count) 首歌曲").font(.caption).foregroundStyle(OrcaTheme.muted)
                Spacer()
                Button { if navigation.canActivateContent() { sortingSongs = true } } label: { Image(systemName: "arrow.up.arrow.down").font(.subheadline).frame(width: 44, height: 44) }.buttonStyle(.plain)
                    .accessibilityLabel("全部歌曲排序").accessibilityValue(model.collection.effectiveSongSort + (model.collection.isSongSortAscending ? "，升序" : "，降序"))
                    .popover(isPresented: $sortingSongs, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                        VStack(spacing: 4) { ForEach(SongSortMode.allCases, id: \.self) { option in
                            Button { model.selectSongSort(option); sortingSongs = false } label: {
                                HStack { Text(option.rawValue); Spacer(); if model.collection.effectiveSongSort == option.rawValue { Image(systemName: model.collection.isSongSortAscending ? "arrow.up" : "arrow.down") } }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        } }.padding(12).frame(width: 180).foregroundStyle(.white).presentationCompactAdaptation(.popover).presentationBackground(OrcaTheme.sheet)
                    }
            }
    }
    private var artistInfoRow: some View {
        HStack {
                Text("\(groups.count) 位歌手").font(.caption).foregroundStyle(OrcaTheme.muted)
                Spacer()
                Button { if navigation.canActivateContent() { sortingArtists = true } } label: {
                    Image(systemName: "arrow.up.arrow.down").font(.subheadline).foregroundStyle(.white).frame(width: 44, height: 44).contentShape(Rectangle())
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
    }
    private var playlistRows: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], alignment: .leading, spacing: 20) {
            ForEach(model.visiblePlaylistIDs, id: \.self) { id in
                Button { if navigation.canActivateContent() { selectedPlaylist = id } } label: {
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            DecodedArtwork(data: model.collection.playlistAppearance?[id]?.artwork, symbol: id == "favorites" ? "heart.fill" : "music.note.list")
                                .padding(model.collection.playlistAppearance?[id]?.artwork == nil ? geo.size.width * 0.1 : 0)
                                .frame(width: geo.size.width, height: geo.size.height).background(OrcaTheme.panel).clipped()
                        }.aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 18))
                        Text(model.playlistTitle(id)).foregroundStyle(id.hasPrefix("stars") ? OrcaTheme.star : .white).lineLimit(1).frame(maxWidth: .infinity, alignment: .center)
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
            Button { if navigation.canActivateContent() { newList = true } } label: {
                GeometryReader { geo in
                    Image(systemName: "plus").font(.system(size: 40, weight: .light))
                        .frame(width: geo.size.width, height: geo.size.height).background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 18))
                }.aspectRatio(1, contentMode: .fit).foregroundStyle(.white).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("新增播放清單")
            if !(model.collection.hiddenPlaylists ?? []).isEmpty {
                Button { hiddenLists = true } label: { Label("管理隱藏清單", systemImage: "eye.slash").frame(minHeight: 44) }.buttonStyle(.plain)
            }
        }.scrollTargetLayout()
    }
    @ViewBuilder private var allSongRows: some View {
        let songs = model.sortedSongs
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: 3), spacing: 20) {
            ForEach(groups, id: \.self) { name in
                let key = model.artistKey(name)
                Button { if navigation.canActivateContent() { selectedArtist = key } } label: {
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
            Button { if navigation.canActivateContent() { newArtist = true } } label: {
                GeometryReader { geo in
                    Image(systemName: "plus").font(.system(size: 38, weight: .light))
                        .frame(width: geo.size.width, height: geo.size.height).background(.white.opacity(0.3), in: Circle())
                }.aspectRatio(1, contentMode: .fit).foregroundStyle(.white).contentShape(Circle())
            }.buttonStyle(.plain).accessibilityLabel("新增歌手")
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
                    Button { guard navigation.canActivateContent() else { return }; model.play(song, queue: ranked, contextName: monthly ? "當月排行榜" : "累計排行榜") } label: {
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
        EntityDetailsForm(title: "新增播放清單", placeholder: "清單名稱", useDefaultCover: true) { name, artwork in
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, clean.count <= 60, !(PlayerModel.systemPlaylistIDs + model.collection.playlists.map(\.id)).contains(where: { model.playlistTitle($0).localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return "名稱須為1～60字，且不可與其他清單重複。" }
            guard model.createPlaylist(clean, artwork: artwork) != nil else { return "無法儲存清單，請檢查名稱與圖片大小。" }
            return nil
        }
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

/// Scroll phase changes only update interaction guards, never observable library data.
private struct HomeScrollActivity: ViewModifier {
    let navigation: HomeLibraryState
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollPhaseChange { _, phase in
                switch phase {
                case .interacting, .decelerating, .animating: navigation.setScrollActive(true)
                case .idle: navigation.setScrollActive(false)
                case .tracking: break // A stationary tap must remain a tap.
                @unknown default: break
                }
            }
                .onDisappear { navigation.setScrollActive(false) }
        } else { content }
    }
}
