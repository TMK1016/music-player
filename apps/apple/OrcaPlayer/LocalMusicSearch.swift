import SwiftUI
import UniformTypeIdentifiers

struct LocalMusicSearchView: View {
    @ObservedObject var model: PlayerModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewState private var folderPicker = false
    @ViewState private var folder: URL?
    @ViewState private var scoped = false
    @ViewState private var scan: LocalMusicScan?
    @ViewState private var selection: Set<String> = []
    @ViewState private var scanning = false
    @ViewState private var importing = false
    @ViewState private var error: String?
    @ViewState private var work: Task<Void, Never>?
    var body: some View {
        VStack(spacing: 16) {
            HStack { Text("搜尋本機歌曲").font(.headline); Spacer(); Button("完成") { dismiss() }.disabled(importing).frame(minHeight: 44) }
            radar.frame(height: 100)
            if scanning { Text("正在搜尋選取的資料夾…").font(.subheadline) }
            else if let scan {
                Text("找到\(scan.songs.count)首可匯入歌曲，已排除\(scan.duplicates)首重複內容").font(.subheadline)
                if scan.unavailable > 0 { Text("\(scan.unavailable)個檔案無法讀取或尚未下載。").font(.caption).foregroundStyle(OrcaTheme.muted) }
                if scan.reachedLimit { Text("本次已檢查10,000個音檔；請選擇較小資料夾繼續搜尋。").font(.caption).foregroundStyle(.orange) }
            } else { Text("選擇「我的iPhone」或已下載音樂所在的資料夾。只搜尋授權範圍，不自動下載雲端檔案。").font(.subheadline).foregroundStyle(OrcaTheme.muted) }
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            if let scan, !scanning {
                HStack {
                    Button(selection.count == scan.songs.count ? "全部取消" : "全選") { selection = selection.count == scan.songs.count ? [] : Set(scan.songs.map(\.id)) }.frame(minHeight: 44)
                    Spacer(); Text("已選\(selection.count)首").font(.caption)
                }
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(scan.songs) { song in
                            Button { if selection.contains(song.id) { selection.remove(song.id) } else { selection.insert(song.id) } } label: {
                                HStack { Image(systemName: selection.contains(song.id) ? "checkmark.circle.fill" : "circle").foregroundStyle(selection.contains(song.id) ? .green : OrcaTheme.muted); VStack(alignment: .leading) { Text(song.name).lineLimit(2); Text(song.url.deletingLastPathComponent().lastPathComponent + " · " + PlayerModel.time(song.duration)).font(.caption).foregroundStyle(OrcaTheme.muted) }; Spacer() }.padding(10).frame(maxWidth: .infinity, minHeight: 48).background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 10)).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityValue(selection.contains(song.id) ? "已勾選" : "未勾選")
                        }
                    }
                }
            } else { Spacer(minLength: 0) }
            HStack {
                Button(scanning ? "取消搜尋" : "選擇資料夾") { if scanning { work?.cancel(); scanning = false } else { folderPicker = true } }.disabled(importing).frame(minHeight: 44)
                Spacer()
                Button(importing ? "匯入中…" : "匯入所選歌曲") {
                    importing = true
                    Task {
                        let urls = scan?.songs.filter { selection.contains($0.id) }.map(\.url) ?? []
                        await model.importFiles(urls)
                        importing = false
                        // Re-scan so failed imports remain available and successful imports disappear.
                        if let folder { begin(folder, reuseScope: true) }
                    }
                }.disabled(selection.isEmpty || scanning || importing || model.isImporting).frame(minHeight: 44)
            }
        }.padding(20).frame(minWidth: 280).themedSheet().interactiveDismissDisabled(importing)
            .fileImporter(isPresented: $folderPicker, allowedContentTypes: [.folder]) { result in
                do { begin(try result.get()) } catch { self.error = error.localizedDescription }
            }
            .onDisappear { work?.cancel(); releaseScope() }
    }
    private var radar: some View {
        ZStack {
            ForEach(1...3, id: \.self) { i in Circle().stroke(OrcaTheme.cyan.opacity(0.22), lineWidth: 1).frame(width: CGFloat(i * 30), height: CGFloat(i * 30)) }
            Image(systemName: scan == nil || scanning ? "antenna.radiowaves.left.and.right" : "checkmark").foregroundStyle(OrcaTheme.cyan)
            if scanning {
                if reduceMotion { ProgressView().offset(y: 38) }
                else {
                    TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                        Rectangle().fill(OrcaTheme.cyan.opacity(0.7)).frame(width: 2, height: 44).offset(y: -22)
                            .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) * 180))
                    }
                }
            }
        }.accessibilityLabel(scanning ? "搜尋中" : "歌曲搜尋")
    }
    private func releaseScope() { if scoped, let folder { folder.stopAccessingSecurityScopedResource() }; scoped = false }
    private func begin(_ url: URL, reuseScope: Bool = false) {
        work?.cancel()
        if !reuseScope { releaseScope(); folder = url; scoped = url.startAccessingSecurityScopedResource() }
        scanning = true; scan = nil; selection = []; error = nil
        work = Task {
            do { let result = try await model.library.scanFolder(url); guard !Task.isCancelled else { return }; scan = result; scanning = false }
            catch { guard !Task.isCancelled else { return }; self.error = error.localizedDescription; scanning = false }
        }
    }
}
