import SwiftUI

struct LibrarySearchView: View {
    @ObservedObject var model: PlayerModel
    @FocusState private var focused: Bool
    @ViewState private var selectedArtist: String?
    private var query: String { model.search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var songs: [AudioTrack] { model.tracks.filter { "\(model.title($0)) \(model.artist($0))".localizedCaseInsensitiveContains(query) } }
    private var artists: [String] { model.libraryIndex.groups.values.map(\.name).filter { $0.localizedCaseInsensitiveContains(query) }.sorted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(OrcaTheme.muted)
                    TextField("搜尋歌曲或歌手", text: $model.search).textFieldStyle(.plain).focused($focused)
                        .accessibilityLabel("搜尋歌曲或歌手")
                    if !model.search.isEmpty { Button { model.search = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 36, height: 44) }.accessibilityLabel("清除搜尋文字") }
                }.padding(.horizontal, 12).frame(minHeight: 44).background(OrcaTheme.elevated, in: Capsule())
                Button { focused = false; model.search = ""; model.showLibrarySearch = false } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }.buttonStyle(.plain).accessibilityLabel("關閉搜尋並返回首頁")
            }
            if query.isEmpty {
                Text("搜尋歌曲與歌手").foregroundStyle(OrcaTheme.muted).padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("歌曲").font(.headline)
                    if songs.isEmpty { Text("沒有符合的歌曲").font(.subheadline).foregroundStyle(OrcaTheme.muted) }
                    let matching = songs
                    LazyVStack(spacing: 12) { ForEach(matching) { song in
                        CollectionSongRow(model: model, track: song, queue: matching, queueName: "搜尋結果").id("search-song:" + song.id)
                    } }.id("search-songs")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("歌手").font(.headline)
                    if artists.isEmpty { Text("沒有符合的歌手").font(.subheadline).foregroundStyle(OrcaTheme.muted) }
                    ForEach(artists, id: \.self) { artist in
                        Button { focused = false; selectedArtist = artist } label: {
                            HStack(spacing: 12) {
                                ArtistAvatar(data: model.libraryIndex.artists[model.artistKey(artist)]?.avatar)
                                Text(artist).foregroundStyle(OrcaTheme.text).lineLimit(1)
                                Spacer(); Image(systemName: "chevron.right")
                            }.padding(12).frame(maxWidth: .infinity, minHeight: 60).background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 12)).contentShape(Rectangle())
                        }.buttonStyle(.plain).id("search-artist:" + model.artistKey(artist))
                    }
                }.id("search-artists")
            }
        }.buttonStyle(.plain).onAppear { focused = true }
            .sheet(isPresented: Binding(get: { selectedArtist != nil }, set: { if !$0 { selectedArtist = nil } })) {
                if let artist = selectedArtist {
                    NavigationStack {
                        ScrollView { LazyVStack(spacing: 12) {
                            let index = model.libraryIndex
                            let works = (index.groups[model.artistKey(artist)]?.songIDs ?? []).compactMap { index.tracks[$0] }
                            ForEach(works) { CollectionSongRow(model: model, track: $0, queue: works, queueName: artist) }
                        }.padding(16) }.navigationTitle(artist)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { selectedArtist = nil } } }
                    }.themedSheet()
                }
            }
    }
}
