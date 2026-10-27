import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct LibraryArtwork: View {
    var data: Data?
    var symbol = "music.note.list"
    var size: CGFloat = 56
    var circular = false
    var body: some View {
        DecodedArtwork(data: data, symbol: symbol)
            .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: circular ? size / 2 : 12))
            .accessibilityHidden(true)
    }
    private var placeholder: some View { Image(systemName: symbol).font(.system(size: size * 0.4)).foregroundStyle(.white).frame(width: size, height: size).background(OrcaTheme.gradient) }
}
struct ArtworkChooser: View {
    @Binding var data: Data?
    var circular = false
    var compactEditor = false
    var fallback: Data? = nil
    @ViewState private var photos = false
    @ViewState private var files = false
    @ViewState private var selectedPhoto: PhotosPickerItem?
    @ViewState private var error: String?
    @ViewState private var pending: CropSelection?
    @ViewState private var loading = false
    var body: some View {
        VStack(spacing: 8) {
            if compactEditor {
                LibraryArtwork(data: data ?? fallback, size: 144)
                    .overlay(alignment: .topTrailing) {
                        Menu {
                            Button("選擇照片") { photos = true }
                            Button("匯入圖片檔") { files = true }
                            Button("移除照片，使用歌手頭貼", role: .destructive) { data = nil }.disabled(data == nil)
                        } label: { Image(systemName: "camera.fill").frame(width: 44, height: 44).background(OrcaTheme.sheet.opacity(0.9), in: Circle()) }.menuStyle(.borderlessButton).menuIndicator(.hidden).accessibilityLabel("封面照片選項")
                    }
            } else {
                Button { photos = true } label: { LibraryArtwork(data: data, symbol: circular ? "person.fill" : "music.note.list", size: 104, circular: circular) }.buttonStyle(.plain).accessibilityLabel("選擇照片")
                HStack(spacing: 24) { Button("更換照片") { photos = true }.frame(minHeight: 44); Button("匯入圖片檔") { files = true }.frame(minHeight: 44) }.buttonStyle(.plain).foregroundStyle(.white)
            }
            if loading { ProgressView("讀取圖片…") }
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
        }
        .photosPicker(isPresented: $photos, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, value in
            guard value != nil else { return }
            Task {
                loading = true
                defer { loading = false; selectedPhoto = nil }
                do { if let bytes = try await value?.loadTransferable(type: Data.self) { try await accept(bytes) } }
                catch { self.error = error.localizedDescription }
            }
        }
        .fileImporter(isPresented: $files, allowedContentTypes: [.image, .jpeg, .png, .heic, .tiff, .gif]) { result in
            Task {
                loading = true
                defer { loading = false }
                do { let bytes = try await ArtworkPipeline.shared.read(result.get()); try await accept(bytes) }
                catch { self.error = error.localizedDescription }
            }
        }
        .sheet(item: $pending) { selection in
            ArtworkCropEditor(bitmap: selection.bitmap, circular: circular) { bytes in data = bytes }
        }
    }
    private func accept(_ bytes: Data) async throws {
        let bitmap = try await ArtworkPipeline.shared.decode(bytes)
        pending = CropSelection(bitmap: bitmap); error = nil
    }
}
private struct CropSelection: Identifiable { let id = UUID(); let bitmap: ArtworkBitmap }

struct PlaylistDetailsEditor: View {
    @ObservedObject var model: PlayerModel
    let playlistID: String
    @Environment(\.dismiss) private var dismiss
    @ViewState private var name = ""
    @ViewState private var artwork: Data?
    @ViewState private var error: String?
    var body: some View {
        VStack(spacing: 20) {
            Text("編輯播放清單").font(.headline)
            ArtworkChooser(data: $artwork)
            TextField("清單名稱", text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("清單名稱")
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            HStack {
                Button("取消") { dismiss() }.frame(minHeight: 44)
                Spacer()
                Button("儲存") { if model.updatePlaylist(playlistID, name: name, artwork: artwork) { dismiss() } else { error = "名稱須為1～60字，且不可與其他清單重複。" } }.frame(minHeight: 44)
            }
        }.padding(24).frame(minWidth: 300).themedSheet()
            .onAppear { name = model.playlistTitle(playlistID); artwork = model.collection.playlistAppearance?[playlistID]?.artwork }
    }
}
struct ArtistDetailsEditor: View {
    @ObservedObject var model: PlayerModel
    let artist: MusicArtist
    @Environment(\.dismiss) private var dismiss
    @ViewState private var name = ""
    @ViewState private var artwork: Data?
    @ViewState private var error: String?
    var body: some View {
        VStack(spacing: 20) {
            Text("編輯歌手資料").font(.headline)
            ArtworkChooser(data: $artwork, circular: true)
            TextField("歌手名稱", text: $name).textFieldStyle(.roundedBorder).accessibilityLabel("歌手名稱")
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            HStack {
                Button("取消") { dismiss() }.frame(minHeight: 44)
                Spacer()
                Button("儲存") {
                    let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty, title.count <= 100, !model.collection.artists.contains(where: { $0.id != artist.id && $0.name.localizedCaseInsensitiveCompare(title) == .orderedSame }) else { error = "名稱須為1～100字，且不可與其他歌手重複。"; return }
                    let id = artist.id.hasPrefix("native:") ? model.editableArtist(named: artist.name).id : artist.id
                    model.updateArtist(id, name: title, avatar: artwork); dismiss()
                }.frame(minHeight: 44)
            }
        }.padding(24).frame(minWidth: 300).themedSheet().onAppear { name = artist.name; artwork = artist.avatar }
    }
}
struct PlaylistSongsEditor: View {
    @ObservedObject var model: PlayerModel
    let playlistID: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if model.isSystemPlaylist(playlistID) && playlistID != "favorites" { Text("此清單依評分或匯入日期自動分類；請從歌曲評分或清單顯示設定調整。").font(.caption) }
                ForEach(model.songs(in: playlistID)) { song in
                    HStack {
                        Text(model.title(song)).lineLimit(1)
                        Spacer()
                        if !model.isSystemPlaylist(playlistID) || playlistID == "favorites" {
                            Button(role: .destructive) { model.togglePlaylistMembership(song.id, playlistID) } label: { Image(systemName: "minus.circle.fill").frame(width: 44, height: 44) }.accessibilityLabel("從清單移除\(model.title(song))，保留音檔")
                        }
                    }
                }
                if model.songs(in: playlistID).isEmpty { Text("清單尚無歌曲") }
            }.scrollContentBackground(.hidden).navigationTitle(model.playlistTitle(playlistID))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 300, minHeight: 350).themedSheet()
    }
}
struct HiddenPlaylistsEditor: View {
    @ObservedObject var model: PlayerModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(model.collection.hiddenPlaylists ?? []).sorted(), id: \.self) { id in
                    Button { model.hidePlaylist(id, hidden: false) } label: {
                        HStack { Text(model.playlistTitle(id)); Spacer(); Label("還原", systemImage: "eye") }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                if (model.collection.hiddenPlaylists ?? []).isEmpty { Text("沒有隱藏的清單") }
                Text("系統清單還原後，仍須有符合的歌曲才會顯示。").font(.caption)
            }.scrollContentBackground(.hidden).navigationTitle("隱藏清單")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 300, minHeight: 350).themedSheet()
    }
}
