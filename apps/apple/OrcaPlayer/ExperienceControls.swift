import SwiftUI

struct TrackPlaylistEditor: View {
    @ObservedObject var model: PlayerModel
    let trackID: String
    @Environment(\.dismiss) private var dismiss
    @ViewState private var name = ""
    @ViewState private var error: String?
    @ViewState private var deleting: String?
    var body: some View {
        NavigationStack {
            List {
                Section("所屬播放清單") {
                    ForEach(model.collection.playlists) { list in
                        Toggle(list.name, isOn: Binding(get: { list.trackIDs.contains(trackID) }, set: { selected in
                            if selected { model.addToPlaylist(trackID, list.id) } else { model.removeFromPlaylist(trackID, list.id) }
                        }))
                        .contextMenu { Button("刪除整份清單（保留音檔）", role: .destructive) { deleting = list.id } }
                    }
                    if model.collection.playlists.isEmpty { Text("建立一份清單，加入目前歌曲。") }
                }
                Section("新增播放清單") {
                    TextField("清單名稱", text: $name).accessibilityLabel("新播放清單名稱")
                    if let error { Text(error).foregroundStyle(.orange).font(.caption) }
                    Button("建立並加入目前歌曲") { create() }
                }
                Section { Text("關閉清單開關只會移除歌曲關聯，音樂檔案會保留。長按清單可刪除整份清單。").font(.caption) }
            }.navigationTitle("播放清單")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 300, minHeight: 350)
            .confirmationDialog("刪除整份播放清單？音樂檔案會保留。", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("刪除清單", role: .destructive) { if let id = deleting { model.deletePlaylist(id) }; deleting = nil }
            }
    }
    private func create() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 60 else { error = "名稱須為1～60字。"; return }
        guard !model.collection.playlists.contains(where: { $0.name.localizedCaseInsensitiveCompare(title) == .orderedSame }) else { error = "已有相同名稱。"; return }
        let before = Set(model.collection.playlists.map(\.id))
        model.createPlaylist(title)
        if let list = model.collection.playlists.first(where: { !before.contains($0.id) }) { model.addToPlaylist(trackID, list.id); name = ""; error = nil }
    }
}

struct SleepTimerEditor: View {
    @ObservedObject var model: PlayerModel
    @Environment(\.dismiss) private var dismiss
    @ViewState private var bySongs = false
    @ViewState private var amount = 10
    private var limit: Int { bySongs ? 100 : 120 }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("倒數方式", selection: $bySongs) {
                        Text("計時倒數").tag(false)
                        Text("歌曲倒數").tag(true)
                    }.pickerStyle(.segmented)
                    HStack {
                        ForEach(bySongs ? [3, 5, 10] : [5, 10, 20], id: \.self) { value in
                            Button("\(value)\(bySongs ? "首" : "分鐘")") { amount = value }
                                .buttonStyle(.bordered).frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    HStack {
                        Text(bySongs ? "自訂首數" : "自訂分鐘")
                        TextField("數量", value: $amount, format: .number).frame(minWidth: 45, maxWidth: 80)
                            .textFieldStyle(.roundedBorder).accessibilityLabel(bySongs ? "歌曲數，1至100" : "分鐘，1至120")
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                        Stepper("數量", value: $amount, in: 1...limit).labelsHidden()
                    }
                    Text("可設定1～\(limit)\(bySongs ? "首" : "分鐘")").font(.caption)
                }
                Section {
                    Text(bySongs ? "包含目前歌曲，僅自然播完才扣除，跳歌不扣除；重播也計數。" : "時間倒數在暫停時仍持續，歸零時停止播放。重開App不恢復倒數。")
                        .font(.caption).foregroundStyle(OrcaTheme.muted)
                    Text("目前：\(model.sleepStatus)")
                    Button("開始倒數") {
                        if bySongs { model.scheduleSleep(songs: amount) } else { model.scheduleSleep(minutes: amount) }
                        dismiss()
                    }.disabled(!(1...limit).contains(amount))
                    Button("取消目前倒數", role: .destructive) { model.cancelSleep(); dismiss() }
                        .disabled(model.sleepDeadline == nil && model.sleepSongsRemaining == nil)
                }
            }.navigationTitle("睡眠模式")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("關閉") { dismiss() } } }
                .onChange(of: bySongs) { _, value in amount = value ? 3 : 10 }
        }.frame(minWidth: 300, minHeight: 350)
    }
}

struct FeedbackEditor: View {
    @Environment(\.dismiss) private var dismiss
    @ViewState private var text = ""
    private var report: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return "Music Player \(version) 意見反饋\n\(text)"
    }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("描述遇到的情況或想改善的地方。匯出後可選擇傳送對象。").font(.subheadline)
                TextEditor(text: $text).accessibilityLabel("反饋內容").frame(minHeight: 160)
                ShareLink(item: report) { Label("匯出反饋", systemImage: "square.and.arrow.up") }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).frame(minHeight: 44)
            }.padding(20).navigationTitle("反饋")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 300, minHeight: 350)
    }
}
struct PrivacyDetails: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("隱私政策 · 本機測試版").font(.title2)
                    Text("更新日期：2026年10月26日")
                    Text("音樂與使用資料").font(.headline)
                    Text("匯入的音樂會複製到App曲庫。歌名、歌手、頭貼、播放清單、收藏、評分、搜尋紀錄、聆聽次數與音效偏好儲存在裝置上，用來提供播放與分類功能。")
                    Text("傳送與分享").font(.headline)
                    Text("目前App沒有內建帳號、廣告或第三方分析SDK，不主動將曲庫、評分或聆聽紀錄傳送給開發者。只有你使用系統分享並選擇目的地後，所選文字才會交由該服務處理。")
                    Text("管理資料").font(.headline)
                    Text("你可以在App內移除清單關聯、刪除App曲庫音檔或清除評分。刪除App內音檔不會刪除外部原始檔案；裝置、iCloud及電腦備份由系統與你所選服務管理。")
                    Text("本政策描述目前測試版的實際功能；若未來加入雲端、帳號或分析服務，會更新說明。可透過反饋頁匯出你的問題。")
                }.frame(maxWidth: 600, alignment: .leading).padding(20)
            }.navigationTitle("隱私政策")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 300, minHeight: 400)
    }
}
