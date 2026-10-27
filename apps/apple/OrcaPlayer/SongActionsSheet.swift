import SwiftUI

struct SongActionsSheet: View {
    @ObservedObject var model: PlayerModel
    let track: AudioTrack
    var playlistID = "all"
    @Environment(\.dismiss) private var dismiss
    @ViewState private var editing = false
    @ViewState private var playlists = false
    @ViewState private var deleting = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    SongArtwork(model: model, track: track, compact: true).frame(width: 48, height: 48)
                    VStack(alignment: .leading) { Text(model.title(track)).font(.headline).lineLimit(2); Text(model.artist(track)).font(.caption).foregroundStyle(OrcaTheme.muted) }
                    Spacer(); Button("完成") { dismiss() }.frame(minHeight: 44)
                }
                Divider()
                Button { model.toggleFavorite(track) } label: { Label(model.favorites.contains(track.id) ? "取消收藏" : "收藏", systemImage: model.favorites.contains(track.id) ? "heart.fill" : "heart").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }
                HStack(spacing: 8) {
                    SlidingStarRating(model: model, trackID: track.id)
                    Spacer(minLength: 0)
                    if model.rating(track.id) > 0 {
                        Button { model.setRating(track.id, 0) } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("清除評分")
                    }
                }
                Button { editing = true } label: { Label("編輯歌曲", systemImage: "square.and.pencil").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }
                Button { playlists = true } label: { Label("加入播放清單", systemImage: "text.badge.plus").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }
                if model.collection.playlists.contains(where: { $0.id == playlistID }) {
                    Button { model.removeFromPlaylist(track.id, playlistID); dismiss() } label: { Label("從此清單移除，保留音檔", systemImage: "minus.circle").frame(minHeight: 44) }
                }
                Button(role: .destructive) { deleting = true } label: { Label("刪除App內音樂檔案", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.disabled(track.isDemo)
            }.padding(20)
        }.frame(minWidth: 280).themedSheet().presentationDetents([.height(520), .large])
            .sheet(isPresented: $editing) { SongEditor(model: model, track: track) }
            .sheet(isPresented: $playlists) { TrackPlaylistEditor(model: model, trackID: track.id) }
            .confirmationDialog("刪除App內音檔？所有清單及歌曲音效綁定也會移除，外部原始檔保留。", isPresented: $deleting, titleVisibility: .visible) {
                Button("確認刪除音檔", role: .destructive) { Task { await model.deleteAudioFile(track); dismiss() } }
                Button("取消", role: .cancel) {}
            }
    }
}
