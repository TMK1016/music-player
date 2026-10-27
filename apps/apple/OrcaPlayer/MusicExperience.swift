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
    @ViewState private var actions = false
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 88
    var body: some View {
        HStack(spacing: 10) {
            Button { model.play(track, queue: queue.isEmpty ? model.tracks : queue, contextName: queueName, playlistID: model.isSystemPlaylist(playlistID) || model.collection.playlists.contains(where: { $0.id == playlistID }) ? playlistID : nil) } label: {
                HStack(spacing: 10) {
                    SongArtwork(model: model, track: track, compact: true).frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.title(track)).font(.body).lineLimit(1).foregroundStyle(OrcaTheme.text)
                        Text(model.artist(track)).font(.caption).lineLimit(1).foregroundStyle(OrcaTheme.muted)
                        Text(model.rating(track.id) > 0 ? String(repeating: "★", count: model.rating(track.id)) : " ")
                            .font(.caption).lineLimit(1).foregroundStyle(OrcaTheme.star)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Button { actions = true } label: { Image(systemName: "ellipsis").foregroundStyle(OrcaTheme.muted).frame(width: 44, height: 44) }.buttonStyle(.plain).accessibilityLabel("管理 \(model.title(track))")
        }.padding(.horizontal, 12).frame(height: rowHeight).background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.selectedID == track.id ? OrcaTheme.cyan.opacity(0.5) : OrcaTheme.line.opacity(0.4)))
            .sheet(isPresented: $actions) { SongActionsSheet(model: model, track: track, playlistID: playlistID) }
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
    @ViewState private var cover: Data?
    @FocusState private var artistFocused: Bool
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 18) {
            Text("編輯歌曲資料").font(.title2)
            HStack { ArtworkChooser(data: $cover); if cover != nil { Button("使用歌手頭貼") { cover = nil } } }
            Text("歌曲名稱").font(.caption)
            TextField("歌名", text: $title).songEditorField()
            Text("歌手").font(.caption)
            TextField("歌手／作者（可留白）", text: $artist).songEditorField().focused($artistFocused)
            if artistFocused && !model.collection.artists.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(model.collection.artists) { item in
                        Button(item.name) { artist = item.name }.buttonStyle(.bordered).frame(minHeight: 44)
                    } }
                }.accessibilityLabel("已有歌手標籤")
            }

            HStack { Button("取消") { dismiss() }; Spacer(); Button("儲存") { model.editSong(track, title: title, artistName: artist); model.setCover(track.id, data: cover); if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { dismiss() } }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 200 || artist.count > 100) }
        }.padding(20) }.frame(minWidth: 280, maxWidth: 500).themedSheet().presentationDetents(artistFocused ? [.height(650), .large] : [.height(580), .large]).onAppear { title = model.title(track); cover = model.details(track.id).cover; artist = model.artist(track) == "未知歌手" ? "" : model.artist(track) }
    }
}
struct ArtistAvatar: View {
    var data: Data?
    var size: CGFloat = 64
    var body: some View { DecodedArtwork(data: data, symbol: "person.fill").frame(width: size, height: size).clipShape(Circle()).accessibilityHidden(true) }
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
                    .frame(maxWidth: .infinity, minHeight: 28).foregroundStyle(model.playbackListID?.hasPrefix("stars") == true ? OrcaTheme.star : OrcaTheme.text).accessibilityLabel("目前播放清單：\(model.playingListTitle)")
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
                SongArtwork(model: model, track: model.track).frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 24).onEnded { value in
                        if value.translation.width < -48 && abs(value.translation.width) > abs(value.translation.height) * 1.5 { changeFace(true) }
                    })
                    .accessibilityLabel("歌曲封面，向左滑動調音")
                    .accessibilityAction(named: "顯示等化器") { changeFace(true) }
            }
            Text(model.title(model.track)).font(.title3.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center).offset(y: -4)
            Text(model.artist(model.track)).font(.caption).foregroundStyle(OrcaTheme.muted).lineLimit(1).offset(y: -4)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                        Button { editingSong = true } label: { Image(systemName: "square.and.pencil").frame(width: 44, height: 44) }.accessibilityLabel("編輯歌曲資訊")
                        SleepMenu(model: model, compact: true)
                        SystemRoutePicker().frame(width: 44, height: 44).accessibilityLabel("選擇音訊輸出裝置")
                        Button { playlists = true } label: { Image(systemName: "text.badge.plus").frame(width: 44, height: 44) }.accessibilityLabel("新增或移除播放清單")
                        PlaybackModeButton(model: model)
                        FavoriteRatingButton(model: model, track: model.track)
                    }.padding(.horizontal, 4).background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                        .opacity(toolsExpanded ? 1 : 0).allowsHitTesting(toolsExpanded).accessibilityHidden(!toolsExpanded)
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
            }.foregroundStyle(OrcaTheme.star).contentShape(Rectangle())
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
                    HStack { SongArtwork(model: model, track: model.track, compact: true).frame(width: 38); VStack(alignment: .leading) { Text(model.title(model.track)).font(.subheadline).lineLimit(1); Text(model.artist(model.track)).font(.caption).foregroundStyle(OrcaTheme.muted).lineLimit(1) }; Spacer(minLength: 0) }.contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("展開正在播放")
                IconButton(symbol: model.isPlaying ? "pause.fill" : "play.fill", label: model.isPlaying ? "暫停" : "播放", active: true) { model.togglePlayback() }
                IconButton(symbol: "forward.end.fill", label: "下一首") { model.next() }
            }.padding(.horizontal, 14).padding(.vertical, 8)
            PlaybackMiniProgress(model: model, clock: model.playbackClock)
        }.background(OrcaTheme.blue.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(OrcaTheme.cyan.opacity(0.7), lineWidth: 1))
            .padding(.horizontal, 10).padding(.vertical, 6)
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
    @ViewState private var localScan = false
    @ViewState private var bindings = false
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button { model.page = .equalizer } label: { Label("等化器調整", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.frame(minHeight: 44)
            Button { sleepEditor = true } label: { Label(model.sleepDeadline == nil && model.sleepSongsRemaining == nil ? "睡眠模式" : "睡眠模式 · \(model.sleepStatus)", systemImage: "timer").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.frame(minHeight: 44)
            ShareLink(item: "Music Player｜你的音樂，你的聲音。") { Label("分享給朋友", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.frame(minHeight: 44)
            Button { feedback = true } label: { Label("反饋", systemImage: "bubble.left.and.text.bubble.right").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.frame(minHeight: 44)
            Button { privacy = true } label: { Label("隱私政策", systemImage: "hand.raised").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }.frame(minHeight: 44)
            HStack { Label("播放來源與輸出", systemImage: "speaker.wave.2"); Spacer(); SystemRoutePicker().frame(width: 44, height: 44) }
                .frame(maxWidth: .infinity, minHeight: 44).accessibilityLabel("本機曲庫，選擇音訊輸出")
            Button { localScan = true } label: { Label("搜尋本機歌曲", systemImage: "wave.3.right.circle").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }

        }
        .sheet(isPresented: $sleepEditor) { SleepTimerEditor(model: model) }
        .sheet(isPresented: $feedback) { FeedbackEditor() }
        .sheet(isPresented: $privacy) { PrivacyDetails() }
        .sheet(isPresented: $localScan) { LocalMusicSearchView(model: model) }
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
