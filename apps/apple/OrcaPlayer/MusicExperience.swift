import SwiftUI
import UniformTypeIdentifiers
import AVKit
#if os(iOS)
import MediaPlayer
#endif

// Explicit property-wrapper alias also supports SDKs that expose a same-name State macro.
typealias ViewState<Value> = State<Value>

struct CollectionSongRow: View {
    @ObservedObject var model: PlayerModel
    let track: AudioTrack
    var queue: [AudioTrack] = []
    var playlistID = "all"
    var queueName = "全部歌曲"
    @ViewState private var editing = false
    @ViewState private var deletion = false
    var body: some View {
        HStack(spacing: 10) {
            Button { model.play(track, queue: queue.isEmpty ? model.tracks : queue, contextName: queueName, playlistID: model.isSystemPlaylist(playlistID) || model.collection.playlists.contains(where: { $0.id == playlistID }) ? playlistID : nil) } label: {
                HStack { AlbumArtwork(variant: track.artwork, compact: true).frame(width: 42); VStack(alignment: .leading, spacing: 4) { Text(model.title(track)).lineLimit(1).foregroundStyle(OrcaTheme.ink); Text(model.artist(track)).font(.caption).lineLimit(1).foregroundStyle(OrcaTheme.ink); if model.rating(track.id) > 0 { Text(String(repeating: "★", count: model.rating(track.id))).font(.caption).foregroundStyle(OrcaTheme.ink) } }; Spacer() }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            FavoriteRatingButton(model: model, track: track, foreground: OrcaTheme.ink)
            Menu {
                Button("編輯歌曲資料") { editing = true }
                Menu("加入播放清單") { ForEach(model.collection.playlists) { list in Button(list.name) { model.addToPlaylist(track.id, list.id) } }; if model.collection.playlists.isEmpty { Text("請先建立自訂清單") } }
                if model.collection.playlists.contains(where: { $0.id == playlistID }) { Button("從此播放清單移除") { model.removeFromPlaylist(track.id, playlistID) } }
                Button("刪除App內音樂檔案…", role: .destructive) { deletion = true }.disabled(track.isDemo)
            } label: { Image(systemName: "ellipsis.circle").foregroundStyle(OrcaTheme.ink).frame(width: 44, height: 44) }.menuStyle(.borderlessButton).menuIndicator(.hidden).accessibilityLabel("管理 \(model.title(track))")
        }.padding(12).background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.selectedID == track.id ? OrcaTheme.ink.opacity(0.5) : OrcaTheme.line.opacity(0.4)))
            .sheet(isPresented: $editing) { SongEditor(model: model, track: track) }
            .confirmationDialog("刪除「\(model.title(track))」的App內音檔？所有清單與歌曲音效綁定也會移除，外部原始檔保留。", isPresented: $deletion, titleVisibility: .visible) {
                Button("確認刪除音檔", role: .destructive) { Task { await model.deleteAudioFile(track) } }; Button("取消", role: .cancel) {}
            }
    }
}
struct FavoriteRatingButton: View {
    @ObservedObject var model: PlayerModel
    let track: AudioTrack
    var foreground = OrcaTheme.cyan
    @ViewState private var rating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Image(systemName: model.favorites.contains(track.id) ? "heart.fill" : "heart")
            .foregroundStyle(foreground).frame(width: 44, height: 44).contentShape(Rectangle())
            .rotationEffect(.degrees(rating && !reduceMotion ? 10 : 0))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.12).repeatCount(4, autoreverses: true), value: rating)
            .gesture(LongPressGesture(minimumDuration: 0.5).exclusively(before: TapGesture()).onEnded { value in
                switch value { case .first: rating = true; case .second: model.toggleFavorite(track) }
            })
            .accessibilityAddTraits(.isButton).accessibilityLabel("收藏與評分")
            .accessibilityValue(model.favorites.contains(track.id) ? "已收藏" : "未收藏")
            .accessibilityAction { model.toggleFavorite(track) }.accessibilityAction(named: "評分") { rating = true }
            .popover(isPresented: $rating) {
                VStack(spacing: 12) {
                    Text("左右滑動評分").font(.headline)
                    SlidingStarRating(model: model, trackID: track.id)
                    HStack { Button("清除評分") { model.setRating(track.id, 0) }; Spacer(); Button("完成") { rating = false } }
                }.padding(20).frame(width: 280).presentationCompactAdaptation(.popover)
                    .presentationBackground(OrcaTheme.panel)
            }
    }
}
struct SongEditor: View {
    @ObservedObject var model: PlayerModel
    let track: AudioTrack
    @Environment(\.dismiss) private var dismiss
    @ViewState private var title = ""
    @ViewState private var artist = ""
    @FocusState private var artistFocused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("編輯歌曲資料").font(.title2)
            Text("歌曲名稱").font(.caption)
            TextField("歌名", text: $title).textFieldStyle(.roundedBorder)
            Text("歌手").font(.caption)
            TextField("歌手／作者（可留白）", text: $artist).textFieldStyle(.roundedBorder).focused($artistFocused)
            if artistFocused && !model.collection.artists.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(model.collection.artists) { item in
                        Button(item.name) { artist = item.name }.buttonStyle(.bordered).frame(minHeight: 44)
                    } }
                }.accessibilityLabel("已有歌手標籤")
            }
            Text("未知資料先由你填寫；不使用AI猜測。改名不改動原始音檔。").font(.caption).foregroundStyle(OrcaTheme.muted)
            HStack { Button("取消") { dismiss() }; Spacer(); Button("儲存") { model.editSong(track, title: title, artistName: artist); if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { dismiss() } }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 200 || artist.count > 100) }
        }.padding(24).frame(minWidth: 280).themedSheet().onAppear { title = model.title(track); artist = model.details(track.id).artistID == nil ? "" : model.artist(track) }
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
/// Both faces share the same PlayerModel; changing the face never reloads audio.
struct MusicPlayerPage: View {
    @ObservedObject var model: PlayerModel
    @ViewState private var showingEQ = false
    @ViewState private var playlists = false
    @ViewState private var editingSong = false
    @ViewState private var toolsExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 6) {
                Text(model.playingListTitle).font(.subheadline.weight(.semibold)).lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 28).accessibilityLabel("目前播放清單：\(model.playingListTitle)")
                if !showingEQ {
                HStack(spacing: 6) {
                    SlidingStarRating(model: model, trackID: model.selectedID, compactDisplay: true)
                    Spacer(minLength: 0)
                    Button { changeFace(true) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text(model.presetName).lineLimit(1).minimumScaleFactor(0.7)
                        }.font(.caption.weight(.semibold)).frame(minHeight: 44)
                    }.buttonStyle(.plain).foregroundStyle(OrcaTheme.cyan)
                        .accessibilityLabel("等化器模式：\(model.presetName)，點選調音")
                }
                }
                if showingEQ {
                    InlineTuningPanel(model: model, useSongPolicy: true, onBack: { changeFace(false) })
                } else {
                    cover
                }
                PlaybackTransport(model: model, compact: geometry.size.height < 420)
            }.padding(.horizontal, 16).padding(.vertical, 4)
                .frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.sheet(isPresented: $playlists) { TrackPlaylistEditor(model: model, trackID: model.selectedID) }
        .sheet(isPresented: $editingSong) { SongEditor(model: model, track: model.track) }
    }
    private var cover: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let side = max(40, min(340, geometry.size.width, geometry.size.height))
                AlbumArtwork(variant: model.track.artwork).frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 24).onEnded { value in
                        if value.translation.width < -48 && abs(value.translation.width) > abs(value.translation.height) * 1.5 { changeFace(true) }
                    })
                    .accessibilityLabel("歌曲封面，向左滑動調音")
                    .accessibilityAction(named: "顯示等化器") { changeFace(true) }
            }
            Text(model.title(model.track)).font(.title3.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
            Text(model.artist(model.track)).font(.caption).foregroundStyle(OrcaTheme.muted).lineLimit(1)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                if toolsExpanded {
                    HStack(spacing: 0) {
                        Button { editingSong = true } label: { Image(systemName: "square.and.pencil").frame(width: 44, height: 44) }.accessibilityLabel("編輯歌曲資訊")
                        SleepMenu(model: model, compact: true)
                        Button { playlists = true } label: { Image(systemName: "text.badge.plus").frame(width: 44, height: 44) }.accessibilityLabel("新增或移除播放清單")
                        FavoriteRatingButton(model: model, track: model.track)
                        PlaybackModeButton(model: model)
                        SystemRoutePicker().frame(width: 44, height: 44).accessibilityLabel("選擇音訊輸出裝置")
                    }.transition(.move(edge: .trailing).combined(with: .opacity))
                }
                Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { toolsExpanded.toggle() } } label: {
                    Image(systemName: toolsExpanded ? "chevron.right" : "chevron.left").frame(width: 44, height: 44)
                }.accessibilityLabel(toolsExpanded ? "收合功能抽屜" : "展開六項播放功能")
            }.buttonStyle(.plain).frame(height: 44).clipped()
        }
    }
    private func changeFace(_ equalizer: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showingEQ = equalizer }
    }
}

struct SlidingStarRating: View {
    @ObservedObject var model: PlayerModel
    let trackID: String
    var compactDisplay = false
    private var visibleStars: Int { compactDisplay && model.rating(trackID) > 0 ? model.rating(trackID) : 5 }
    @Environment(\.layoutDirection) private var direction
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(1...visibleStars, id: \.self) { value in
                    Button { model.setRating(trackID, value) } label: {
                        Image(systemName: value <= model.rating(trackID) ? "star.fill" : "star")
                            .font(.system(size: 19, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.plain)
                }
            }.foregroundStyle(OrcaTheme.cyan).contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                    let x = direction == .rightToLeft ? geometry.size.width - value.location.x : value.location.x
                    model.setRating(trackID, RatingInteraction.value(at: x, width: geometry.size.width))
                })
        }.frame(width: compactDisplay ? max(44, CGFloat(visibleStars * 28)) : 220, height: 44)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("歌曲評分")
            .accessibilityValue(model.rating(trackID) == 0 ? "未評分，五星空心" : "\(model.rating(trackID)) 顆星，共5顆")
            .accessibilityAdjustableAction { action in
                switch action {
                case .increment: model.setRating(trackID, min(5, model.rating(trackID) + 1))
                case .decrement: model.setRating(trackID, max(0, model.rating(trackID) - 1))
                @unknown default: break
                }
            }
            .accessibilityAction(named: "清除評分") { model.setRating(trackID, 0) }
            .contextMenu { Button("清除評分") { model.setRating(trackID, 0) } }
    }
}

struct PlaybackTransport: View {
    @ObservedObject var model: PlayerModel
    var compact = false
    private var mode: String { model.repeatOne ? "單曲循環" : model.shuffle ? "隨機播放" : "歌單循環" }
    private var symbol: String { model.repeatOne ? "repeat.1" : model.shuffle ? "shuffle" : "repeat" }
    var body: some View {
        VStack(spacing: compact ? 2 : 6) {
            PlaybackSeekBar(model: model, clock: model.playbackClock)
            HStack {
                Spacer(minLength: 4)
                IconButton(symbol: "backward.end.fill", label: "上一首", size: 44) { model.previous() }
                Spacer(minLength: 4)
                Button { model.togglePlayback() } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 25, weight: .semibold)).foregroundStyle(OrcaTheme.background)
                        .frame(width: compact ? 44 : 64, height: compact ? 44 : 64).background(OrcaTheme.gradient, in: Circle())
                }.buttonStyle(.plain).accessibilityLabel(model.isPlaying ? "暫停" : "播放")
                Spacer(minLength: 4)
                IconButton(symbol: "forward.end.fill", label: "下一首", size: 44) { model.next() }
                Spacer(minLength: 4)
            }
        }.padding(.bottom, 12).frame(maxWidth: 600).frame(maxWidth: .infinity)
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
            PlaybackMiniProgress(model: model, clock: model.playbackClock)
        }.background(OrcaTheme.elevated)
    }
}
struct SleepMenu: View {
    @ObservedObject var model: PlayerModel
    var compact = false
    @ViewState private var custom = false
    var body: some View {
        Button { custom = true } label: {
            if compact {
                Image(systemName: model.sleepDeadline != nil || model.sleepSongsRemaining != nil ? "timer.circle.fill" : "timer").frame(width: 44, height: 44)
            } else { Label("睡眠模式", systemImage: "timer") }
        }.accessibilityLabel("睡眠模式：\(model.sleepStatus)")
            .sheet(isPresented: $custom) { SleepTimerEditor(model: model) }
    }
}
struct MusicSettingsView: View {
    @ObservedObject var model: PlayerModel
    @ViewState private var duplicates = false
    @ViewState private var sleepEditor = false
    @ViewState private var feedback = false
    @ViewState private var privacy = false
    @ViewState private var advanced = false
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button { model.page = .equalizer } label: { Label("等化器調整", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.frame(minHeight: 44)
            Button { sleepEditor = true } label: { Label(model.sleepDeadline == nil && model.sleepSongsRemaining == nil ? "睡眠模式" : "睡眠模式 · \(model.sleepStatus)", systemImage: "timer").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.frame(minHeight: 44)
            ShareLink(item: "Music Player｜你的音樂，你的聲音。") { Label("分享給朋友", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.frame(minHeight: 44)
            Button { feedback = true } label: { Label("反饋", systemImage: "bubble.left.and.text.bubble.right").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.frame(minHeight: 44)
            Button { privacy = true } label: { Label("隱私政策", systemImage: "hand.raised").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.frame(minHeight: 44)
            DisclosureGroup("更多設定") {
                VStack(alignment: .leading, spacing: 18) {
            Panel(padding: 18) { VStack(alignment: .leading, spacing: 14) { Text("播放來源與輸出").font(.headline); Text("音樂來源：本機曲庫"); OutputRouteRow(); Text("藍牙車機／耳機是輸出裝置，請先在系統配對。此App不接收其他手機的藍牙音樂，也不控制其他播放器的EQ。").font(.caption).foregroundStyle(OrcaTheme.muted) } }
            Button("進階音場與歌曲綁定") { advanced = true }.frame(minHeight: 44)
            Picker("音效套用方式", selection: Binding(get: { model.useSongProfiles }, set: { model.setSongProfilePolicy($0) })) {
                Text("全部使用相同音效").tag(false)
                Text("依歌曲套用").tag(true)
            }.pickerStyle(.segmented)
            Button("開發日誌") { model.page = .developmentLog }
            Text("Music Player \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—") · build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—")")
                .font(.caption.monospaced()).foregroundStyle(OrcaTheme.cyan).accessibilityIdentifier("app-version")
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
        .sheet(isPresented: $sleepEditor) { SleepTimerEditor(model: model) }
        .sheet(isPresented: $feedback) { FeedbackEditor() }
        .sheet(isPresented: $privacy) { PrivacyDetails() }
        .sheet(isPresented: $advanced) { ScrollView { ProfileControls(model: model).padding(20) }.frame(minWidth: 320, minHeight: 400) }
    }
}
#if os(iOS)
struct SystemRoutePicker: View {
    var body: some View {
        ZStack {
            NativeSystemRoutePicker()
            Image(systemName: "speaker.wave.2").foregroundStyle(OrcaTheme.cyan).allowsHitTesting(false).accessibilityHidden(true)
        }.accessibilityLabel("選擇音訊輸出裝置")
    }
}
private struct NativeSystemRoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(); view.prioritizesVideoDevices = false
        view.tintColor = .clear; view.activeTintColor = .clear
        return view
    }
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
