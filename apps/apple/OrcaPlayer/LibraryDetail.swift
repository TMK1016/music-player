import SwiftUI

/// Collection controls share one selected ID with the centered cover carousel.
struct LibraryDetailPage: View {
    @ObservedObject var model: PlayerModel
    @ObservedObject private var navigation: HomeLibraryState
    let ids: [String]
    let artist: Bool
    @ViewState private var editing = false
    @ViewState private var adding = false
    init(model: PlayerModel, ids: [String], artist: Bool) {
        self.model = model; self.navigation = model.homeState; self.ids = ids; self.artist = artist
    }
    private var selectedID: String { (artist ? navigation.selectedArtist : navigation.selectedPlaylist) ?? ids.first ?? "" }
    private var visibleIDs: [String] { ids.contains(selectedID) ? ids : ids + [selectedID] }
    private func title(_ id: String) -> String {
        if !artist { return model.playlistTitle(id) }
        return model.libraryIndex.groups[id]?.name ?? model.collection.artists.first(where: { $0.id == id })?.name ?? String(id.dropFirst(id.hasPrefix("native:") ? 7 : 0))
    }
    private func artwork(_ id: String) -> Data? {
        artist ? (model.libraryIndex.artists[id]?.avatar ?? model.collection.artists.first(where: { $0.id == id })?.avatar) : model.collection.playlistAppearance?[id]?.artwork
    }
    private var songs: [AudioTrack] {
        if !artist { return model.songs(in: selectedID) }
        let index = model.libraryIndex
        return (index.groups[selectedID]?.songIDs ?? []).compactMap { index.tracks[$0] }
    }
    private var selectedArtist: MusicArtist {
        model.collection.artists.first(where: { $0.id == selectedID }) ?? MusicArtist(id: selectedID, name: title(selectedID), avatar: artwork(selectedID))
    }
    private var canAdd: Bool { artist || selectedID == "favorites" || !model.isSystemPlaylist(selectedID) }
    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Button { navigation.returnToRoot() } label: { Label("返回曲庫", systemImage: "chevron.left").frame(minHeight: 44).contentShape(Rectangle()) }.buttonStyle(.plain).padding(.horizontal, 20).id("detail-top")
                    carousel
                    Text(title(selectedID)).font(.title.bold()).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.horizontal, 20)
                    HStack(spacing: 12) {
                        Text("\(songs.count) 首歌曲").font(.subheadline).foregroundStyle(OrcaTheme.muted)
                        Spacer(minLength: 0)
                        Button { adding = true } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                            .accessibilityLabel("搜尋並加入歌曲").disabled(!canAdd)
                            .help(canAdd ? "從現有曲庫選擇歌曲" : "此清單依日期或評分自動分類")
                        Button { editing = true } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel(artist ? "編輯歌手資料" : "編輯播放清單")
                        Button {
                            if !artist { model.togglePlaylistPlayback(selectedID) }
                            else if let first = songs.first { model.play(first, queue: songs, contextName: title(selectedID)) }
                        } label: {
                            Image(systemName: !artist && model.isCurrentPlaylist(selectedID) && model.isPlaying ? "pause.fill" : "play.fill").foregroundStyle(.black).frame(width: 48, height: 48).background(.green, in: Circle())
                        }.accessibilityLabel(!artist && model.isCurrentPlaylist(selectedID) && model.isPlaying ? "暫停清單" : "播放全部").disabled(songs.isEmpty)
                    }.buttonStyle(.plain).padding(.horizontal, 20)
                    if !canAdd { Text("此清單依日期或評分自動分類；可透過收藏、評分或匯入歌曲調整內容。").font(.caption).foregroundStyle(OrcaTheme.muted).padding(.horizontal, 20) }
                    ForEach(songs) { song in
                        CollectionSongRow(model: model, track: song, queue: songs, playlistID: artist ? "all" : selectedID, queueName: title(selectedID)).padding(.horizontal, 20)
                    }
                }.padding(.vertical, 12)
            }.onChange(of: selectedID) { _, _ in reader.scrollTo("detail-top", anchor: .top) }
        }.background { CollectionDetailBackdrop(data: artwork(selectedID)) }
        .sheet(isPresented: $editing) {
            if artist {
                ArtistDetailsEditor(model: model, artist: selectedArtist) { id in navigation.selectDetail(id, artist: true) }
            } else { PlaylistDetailsEditor(model: model, playlistID: selectedID) }
        }
        .sheet(isPresented: $adding) {
            CollectionSongPicker(model: model, title: title(selectedID), existing: Set(songs.map(\.id)), artist: artist) { selected in
                if artist {
                    if let id = model.assignSongs(selected, toArtistNamed: title(selectedID)) { navigation.selectDetail(id, artist: true) }
                } else { model.addSongs(selected, toPlaylist: selectedID) }
            }
        }
    }
    private var carousel: some View {
        GeometryReader { geo in
            let side = min(240.0, geo.size.width * 0.64)
            CollectionCoverCarousel(ids: visibleIDs, selection: Binding(get: { selectedID }, set: { navigation.selectDetail($0, artist: artist) }), side: side, inset: max(0, (geo.size.width - side) / 2), title: title, artwork: artwork)

        }.frame(height: 250)
    }
}

/// A local scroll binding separates layout reports from the selected collection.
/// Restore the requested ID after layout before accepting visible-position reports.
private struct CollectionCoverCarousel: View {
    let ids: [String]
    @Binding var selection: String
    let side: CGFloat
    let inset: CGFloat
    let title: (String) -> String
    let artwork: (String) -> Data?
    @ViewState private var position: String?
    @ViewState private var ready = false
    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 16) {
                    ForEach(ids, id: \.self) { id in
                        Button { selection = id } label: {
                            CollectionDetailCover(data: artwork(id)).frame(width: side, height: side)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .brightness(id == selection ? 0 : -0.35).scaleEffect(id == selection ? 1 : 0.93)
                        }.buttonStyle(.plain).id(id).accessibilityLabel("切換至：\(title(id))")
                            .accessibilityValue(id == selection ? "目前選取" : "相鄰封面")
                    }
                }.scrollTargetLayout()
            }.contentMargins(.horizontal, inset, for: .scrollContent)
                .scrollIndicators(.hidden).scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $position, anchor: .center)
                .task {
                    ready = false
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    position = selection
                    reader.scrollTo(selection, anchor: .center)
                    ready = true
                }
                .onChange(of: selection) { _, id in
                    guard position != id else { return }
                    position = id
                    reader.scrollTo(id, anchor: .center)
                }
                .onChange(of: position) { _, id in
                    guard ready, let id, ids.contains(id), id != selection else { return }
                    selection = id
                }
        }
    }
}

private struct CollectionDetailCover: View {
    let data: Data?
    var body: some View {
        if let data { DecodedArtwork(data: data).clipped() }
        else { AlbumArtwork(variant: 0, compact: true).equatable() }
    }
}
private struct CollectionDetailBackdrop: View {
    let data: Data?
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                OrcaTheme.background
                if let data { DecodedArtwork(data: data, maxPixelSize: 128).frame(width: geo.size.width, height: 350).clipped().blur(radius: 30).opacity(0.5) }
                else { OrcaTheme.blue.opacity(0.25).frame(height: 350) }
                LinearGradient(colors: [.clear, OrcaTheme.background], startPoint: .top, endPoint: .bottom).frame(height: 380)
            }.clipped()
        }.allowsHitTesting(false)
    }
}

private struct CollectionSongPicker: View {
    @ObservedObject var model: PlayerModel
    let title: String
    let existing: Set<String>
    let artist: Bool
    let apply: (Set<String>) -> Void
    @Environment(\.dismiss) private var dismiss
    @ViewState private var search = ""
    @ViewState private var selection: Set<String> = []
    private var matches: [AudioTrack] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.sortedSongs.filter { query.isEmpty || "\(model.title($0)) \(model.artist($0))".localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        VStack(spacing: 16) {
            Text("加入歌曲至 \(title)").font(.headline).lineLimit(2)
            TextField("搜尋歌名或歌手", text: $search).songEditorField().accessibilityLabel("搜尋要加入的歌曲")
            if artist { Text("所選歌曲的歌手將改為「\(title)」，並從原歌手分類移出。").font(.caption).foregroundStyle(OrcaTheme.muted) }
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(matches) { song in
                        Button {
                            if selection.contains(song.id) { selection.remove(song.id) } else { selection.insert(song.id) }
                        } label: {
                            HStack {
                                Image(systemName: existing.contains(song.id) || selection.contains(song.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(existing.contains(song.id) ? .green : OrcaTheme.cyan)
                                VStack(alignment: .leading, spacing: 3) { Text(model.title(song)).lineLimit(1); Text(model.artist(song)).font(.caption).foregroundStyle(OrcaTheme.muted).lineLimit(1) }
                                Spacer(minLength: 0)
                            }.padding(10).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 10)).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(existing.contains(song.id)).accessibilityValue(existing.contains(song.id) ? "已加入" : selection.contains(song.id) ? "已勾選" : "未勾選")
                    }
                    if matches.isEmpty { Text("找不到符合的歌曲").foregroundStyle(OrcaTheme.muted) }
                }
            }
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("加入 \(selection.count) 首") { apply(selection); dismiss() }.disabled(selection.isEmpty)
            }.buttonStyle(.bordered).frame(minHeight: 44)
        }.padding(20).frame(minWidth: 280).themedSheet()
    }
}
