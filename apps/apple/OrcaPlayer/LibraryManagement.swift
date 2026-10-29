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
    var removalLabel = "移除照片，使用預設圖片"
    var useDefaultCover = false
    @ViewState private var photos = false
    @ViewState private var files = false
    @ViewState private var selectedPhoto: PhotosPickerItem?
    @ViewState private var error: String?
    @ViewState private var pending: CropSelection?
    @ViewState private var loading = false
    var body: some View {
        VStack(spacing: 8) {
            if compactEditor {
                Group {
                    if useDefaultCover && data == nil && fallback == nil {
                        AlbumArtwork(variant: 0, compact: true).equatable().frame(width: 144, height: 144).clipShape(RoundedRectangle(cornerRadius: 12))
                    } else { LibraryArtwork(data: data ?? fallback, symbol: circular ? "person.fill" : "music.note.list", size: 144, circular: circular) }
                }
                    .overlay(alignment: .topTrailing) {
                        Menu {
                            Button("選擇照片") { photos = true }
                            Button("匯入圖片檔") { files = true }
                            Button(removalLabel, role: .destructive) { data = nil }.disabled(data == nil)
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

/// Shared sheet geometry for create/edit artist and playlist metadata.
struct EntityDetailsForm: View {
    let title: String
    let placeholder: String
    let circular: Bool
    let useDefaultCover: Bool
    let save: (String, Data?) -> String?
    @Environment(\.dismiss) private var dismiss
    @ViewState private var name: String
    @ViewState private var artwork: Data?
    @ViewState private var error: String?
    init(title: String, placeholder: String, initialName: String = "", initialArtwork: Data? = nil, circular: Bool = false, useDefaultCover: Bool = false, save: @escaping (String, Data?) -> String?) {
        self.title = title; self.placeholder = placeholder; self.circular = circular; self.useDefaultCover = useDefaultCover; self.save = save
        _name = State(initialValue: initialName); _artwork = State(initialValue: initialArtwork)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                ArtworkChooser(data: $artwork, circular: circular, compactEditor: true, useDefaultCover: useDefaultCover)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                TextField(placeholder, text: $name).songEditorField().accessibilityLabel(placeholder)
                if let error { Text(error).font(.caption).foregroundStyle(.orange) }
                HStack {
                    Button("取消") { dismiss() }.foregroundStyle(.white).frame(minWidth: 44, minHeight: 44)
                    Spacer()
                    Button("儲存") {
                        error = save(name, artwork)
                        if error == nil { dismiss() }
                    }.foregroundStyle(.white).frame(minWidth: 44, minHeight: 44).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.buttonStyle(.plain)
            }.padding(24)
        }.frame(minWidth: 280, maxWidth: 500).themedSheet().presentationDetents([.height(480), .large])
    }
}
struct PlaylistDetailsEditor: View {
    @ObservedObject var model: PlayerModel
    let playlistID: String
    var body: some View {
        EntityDetailsForm(title: "編輯播放清單", placeholder: "清單名稱", initialName: model.playlistTitle(playlistID), initialArtwork: model.collection.playlistAppearance?[playlistID]?.artwork, useDefaultCover: true) { name, artwork in
            model.updatePlaylist(playlistID, name: name, artwork: artwork, replaceArtwork: true) ? nil : "名稱須為1～60字，且不可與其他清單重複。"
        }
    }
}
struct ArtistDetailsEditor: View {
    @ObservedObject var model: PlayerModel
    let artist: MusicArtist
    var onSaved: ((String) -> Void)? = nil
    var body: some View {
        EntityDetailsForm(title: "編輯歌手資料", placeholder: "歌手名稱", initialName: artist.name, initialArtwork: artist.avatar, circular: true) { name, artwork in
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, clean.count <= 100, !model.collection.artists.contains(where: { $0.id != artist.id && $0.name.localizedCaseInsensitiveCompare(clean) == .orderedSame }) else { return "名稱須為1～100字，且不可與其他歌手重複。" }
            guard artwork == nil || artwork!.count <= 5_000_000 else { return "圖片須小於5 MB。" }
            let id = artist.id.hasPrefix("native:") ? model.editableArtist(named: artist.name).id : artist.id
            model.updateArtist(id, name: clean, avatar: artwork, replaceAvatar: true); onSaved?(id)
            return nil
        }
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
