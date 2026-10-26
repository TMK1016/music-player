import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 850
            HStack(spacing: 0) {
                if wide { sidebar.frame(width: 210) }
                VStack(spacing: 0) {
                    if !(model.page == .player && geometry.size.height < 450) { header(wide: wide) }
                    if model.page == .player {
                        MusicPlayerPage(model: model)
                    } else if model.page == .equalizer {
                        InlineTuningPanel(model: model).padding(12)
                    } else { ScrollView {
                        Group {
                            switch model.page {
                            case .settings: MusicSettingsView(model: model)
                            case .player: MusicPlayerPage(model: model)
                            case .library: MusicHomeView(model: model)
                            case .equalizer: EqualizerPage(model: model)
                            case .developmentLog: DevelopmentLogView(model: model)
                            }
                        }.padding(wide ? 28 : (model.page == .equalizer ? 12 : 20))
                    }.id(model.page.rawValue) }
                    if model.hasPlaybackSession && model.page != .player { CompactMusicPlayer(model: model) }
                    if !wide { mobileNavigation }
                }
            }.background(OrcaTheme.background).foregroundStyle(OrcaTheme.text)
        }
        .task { await model.loadLibrary() }
        .fileImporter(isPresented: $model.showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): Task { await model.importFiles(urls) }
            case .failure(let error): model.message = error.localizedDescription
            }
        }
        .alert("Music Player", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("了解", role: .cancel) { model.message = nil }
        } message: { Text(model.message ?? "") }
        .modifier(PresetEditorPresentation(model: model))
        .sheet(isPresented: $model.showQueue) { QueueView(model: model) }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path").font(.system(size: 26, weight: .light)).foregroundStyle(OrcaTheme.cyan)
                Text("MUSIC").font(.system(size: 25, weight: .bold, design: .rounded)).tracking(5)
            }.padding(.top, 38)
            Text("PLAY YOUR SOUND").font(.system(size: 8, weight: .medium, design: .monospaced)).tracking(2.1).foregroundStyle(OrcaTheme.muted).padding(.top, 8)
            Eyebrow(text: "WORKSPACE").padding(.top, 53).padding(.bottom, 15)
            ForEach(PlayerPage.allCases) { page in
                Button {
                    model.page = page
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: page.symbol).frame(width: 20)
                        Text(page.rawValue).font(.system(size: 13, weight: .medium))
                        Spacer()
                        if model.page == page { Circle().fill(OrcaTheme.cyan).frame(width: 4, height: 4) }
                    }.foregroundStyle(model.page == page ? OrcaTheme.text : OrcaTheme.muted)
                        .padding(.horizontal, 14).padding(.vertical, 14)
                        .background(model.page == page ? OrcaTheme.blue.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain).padding(.bottom, 5)
            }
            Eyebrow(text: "YOUR COLLECTION").padding(.top, 34).padding(.bottom, 17)
            Button {
                model.page = .library; model.favoritesOnly = true
            } label: {
                Label("喜愛的歌曲", systemImage: "heart").font(.system(size: 13)).foregroundStyle(OrcaTheme.muted)
            }.buttonStyle(.plain).padding(.leading, 14)
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(OrcaTheme.cyan)
                Text("為每段旅程\n找到你的聲音。")
                    .font(.system(size: 15, weight: .medium)).lineSpacing(5)
                Text("MUSIC PLAYER / 0.9.0").font(.system(size: 9, design: .monospaced)).foregroundStyle(OrcaTheme.muted)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(colors: [OrcaTheme.blue.opacity(0.17), OrcaTheme.panel], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 15))
                .padding(.bottom, 22)
        }.padding(.horizontal, 20).background(OrcaTheme.sidebar)
            .overlay(alignment: .trailing) { Rectangle().fill(OrcaTheme.line.opacity(0.6)).frame(width: 1) }
    }

    private func header(wide: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if wide { Eyebrow(text: "YOUR SOUND. YOUR JOURNEY.") }
                    Text(model.page == .library ? "你的音樂庫" : model.page.rawValue)
                        .font(.system(size: wide ? 25 : 23, weight: .semibold))
                }
                Spacer()
                if model.page == .library {
                    Button { model.showLibrarySearch.toggle(); if !model.showLibrarySearch { model.search = "" } } label: { Image(systemName: "magnifyingglass").frame(width: 44, height: 44) }.accessibilityLabel("搜尋歌曲")
                    Button { model.showImporter = true } label: { Image(systemName: "plus").frame(width: 44, height: 44) }.disabled(model.isImporting).accessibilityLabel("匯入音樂")
                } else if wide { Tag(text: "本機播放", symbol: "waveform") }
            }.padding(.horizontal, wide ? 28 : 20).padding(.top, wide ? 26 : 16).padding(.bottom, 15)
            if model.page != .player && model.page != .library && model.page != .equalizer { HStack(spacing: 6) {
                Image(systemName: "info.circle").foregroundStyle(OrcaTheme.cyan)
                Text(model.statusText)
                Spacer(minLength: 0)
            }.font(.system(size: 11)).foregroundStyle(OrcaTheme.muted)
                .padding(.horizontal, wide ? 28 : 20).padding(.bottom, 13) }
            Rectangle().fill(OrcaTheme.line.opacity(0.7)).frame(height: 1)
        }
    }

    private var mobileNavigation: some View {
        HStack(spacing: 0) {
            ForEach([PlayerPage.library, .player, .settings]) { page in
                Button { model.page = page } label: {
                    VStack(spacing: 6) {
                        Image(systemName: page.symbol).font(.system(size: 18))
                        Text(page.rawValue).font(.system(size: 10))
                    }.foregroundStyle(model.page == page ? OrcaTheme.cyan : OrcaTheme.muted)
                        .frame(maxWidth: .infinity).frame(minHeight: 58).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.padding(.top, 5).background(OrcaTheme.sidebar)
    }
}

struct TransportControls: View {
    @ObservedObject var model: PlayerModel
    var large = false
    var body: some View {
        VStack(spacing: 13) {
            VStack(spacing: 0) {
                Slider(value: $model.progress, in: 0...1).accessibilityLabel("播放進度").tint(OrcaTheme.cyan)
                HStack { Text(model.elapsed); Spacer(); Text(model.remaining) }
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(OrcaTheme.muted)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: large ? 24 : 18) {
                    IconButton(symbol: "shuffle", label: "隨機播放", active: model.shuffle) { model.shuffle.toggle() }
                    primaryButtons
                    IconButton(symbol: "repeat", label: "整份歌單循環", active: model.repeatAll) { model.repeatAll.toggle() }
                }
                HStack(spacing: 24) { primaryButtons }
            }.frame(maxWidth: .infinity)
        }
    }
    @ViewBuilder private var primaryButtons: some View {
                IconButton(symbol: "backward.end.fill", label: "上一首", size: large ? 60 : 44) { model.previous() }
                Button { model.togglePlayback() } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: large ? 30 : 24, weight: .semibold))
                        .offset(x: model.isPlaying ? 0 : 2)
                        .foregroundStyle(Color(hex: 0x07182B))
                        .frame(width: large ? 86 : 62, height: large ? 86 : 62)
                        .background(OrcaTheme.gradient, in: Circle())
                        .shadow(color: OrcaTheme.blue.opacity(0.25), radius: 18, y: 5)
                }.buttonStyle(.plain).accessibilityLabel(model.isPlaying ? "暫停" : "播放")
                IconButton(symbol: "forward.end.fill", label: "下一首", size: large ? 60 : 44) { model.next() }
    }
}

struct MiniPlayer: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        HStack(spacing: 14) {
            AlbumArtwork(variant: model.track.artwork, compact: true).frame(width: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.track.title).font(.system(size: 12, weight: .medium))
                Text(model.track.artist).font(.system(size: 10)).foregroundStyle(OrcaTheme.muted)
            }
            Spacer()
            IconButton(symbol: "backward.end.fill", label: "上一首") { model.previous() }
            IconButton(symbol: model.isPlaying ? "pause.fill" : "play.fill", label: "播放或暫停", active: true) { model.togglePlayback() }
            IconButton(symbol: "forward.end.fill", label: "下一首") { model.next() }
            Spacer()
            Image(systemName: "speaker.wave.2").foregroundStyle(OrcaTheme.muted)
            Slider(value: $model.volume).frame(width: 100).accessibilityLabel("播放音量")
            IconButton(symbol: "list.bullet", label: "播放佇列") { model.showQueue = true }
        }.padding(.horizontal, 25).padding(.vertical, 15).background(OrcaTheme.sidebar)
            .overlay(alignment: .top) { Rectangle().fill(OrcaTheme.line).frame(height: 1) }
    }
}
