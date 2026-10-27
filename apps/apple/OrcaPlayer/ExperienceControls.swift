import SwiftUI

struct TrackPlaylistEditor: View {
    @ObservedObject var model: PlayerModel
    let trackID: String
    @Environment(\.dismiss) private var dismiss
    @ViewState private var name = ""
    @ViewState private var error: String?
    var body: some View {
        NavigationStack {
            List {
                Section("所屬播放清單") {
                    ForEach(model.playlistPickerIDs, id: \.self) { id in
                        HStack {
                            Button {
                                if !model.isSystemPlaylist(id) || id == "favorites" { model.togglePlaylistMembership(trackID, id) }
                            } label: {
                                HStack { Text(model.playlistTitle(id)).foregroundStyle(id.hasPrefix("stars") ? OrcaTheme.star : OrcaTheme.text); Spacer(); Image(systemName: model.containsSong(trackID, inPlaylist: id) ? "checkmark.circle.fill" : "circle").foregroundStyle(model.containsSong(trackID, inPlaylist: id) ? .green : OrcaTheme.muted) }
                                    .frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(model.isSystemPlaylist(id) && id != "favorites")
                        }
                    }
                    if model.collection.playlists.isEmpty { Text("建立一份清單，加入目前歌曲。") }
                }
                Section("新增播放清單") {
                    TextField("清單名稱", text: $name).accessibilityLabel("新播放清單名稱")
                    if let error { Text(error).foregroundStyle(.orange).font(.caption) }
                    Button("建立並加入目前歌曲") { create() }
                }
                Section { Text("點擊清單可加入／移除目前歌曲，音檔會保留。評分與最近新增清單僅顯示自動分類狀態。").font(.caption) }
            }.scrollContentBackground(.hidden).navigationTitle("加入播放清單")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 300, minHeight: 350).themedSheet()
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
    @ViewState private var selectedChoice = 10
    private var limit: Int { bySongs ? 100 : 120 }
    private var presets: [Int] { bySongs ? [3, 5, 10] : [5, 10, 20] }
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("睡眠模式").font(.title2.bold()); Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("關閉睡眠模式")
            }
            Picker("倒數方式", selection: $bySongs) { Text("計時倒數").tag(false); Text("歌曲倒數").tag(true) }.pickerStyle(.segmented).labelsHidden()
                .onChange(of: bySongs) { _, value in amount = value ? 3 : 10; selectedChoice = amount }
            ScrollView { VStack(spacing: 12) {
            Picker("倒數選擇", selection: $selectedChoice) {
                ForEach(presets, id: \.self) { value in Text("\(value) \(bySongs ? "首歌" : "分鐘")").tag(value) }
                Text("自訂\(bySongs ? "首數" : "時間")").tag(-1)
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #else
            .pickerStyle(.inline)
            #endif
            .frame(height: 150).clipped()
                .onChange(of: selectedChoice) { _, value in if value > 0 { amount = value } }
            if selectedChoice == -1 {
                Picker(bySongs ? "自訂首數" : "自訂分鐘", selection: $amount) {
                    ForEach(1...limit, id: \.self) { value in Text("\(value) \(bySongs ? "首歌" : "分鐘")").tag(value) }
                }
                #if os(iOS)
                .pickerStyle(.wheel)
                #else
                .pickerStyle(.menu)
                #endif
                .frame(height: 110).clipped()
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let end = bySongs ? model.estimatedEnd(afterSongs: amount) : context.date.addingTimeInterval(Double(amount) * 60)
                Text("預計結束 \(end.formatted(date: .omitted, time: .shortened))\(bySongs ? "（估計）" : "")").font(.caption).foregroundStyle(OrcaTheme.muted)
            }
            SleepCountdownStatus(model: model)
            }.frame(maxWidth: .infinity) }
            Spacer(minLength: 0)
            HStack(spacing: 16) {
                Button { model.cancelSleep(); dismiss() } label: { Label("取消倒數", systemImage: "xmark").frame(maxWidth: .infinity, minHeight: 48) }
                    .buttonStyle(.plain).foregroundStyle(.white).background(Color.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 14)).disabled(model.sleepDeadline == nil && model.sleepSongsRemaining == nil)
                Button { if bySongs { model.scheduleSleep(songs: amount) } else { model.scheduleSleep(minutes: amount) }; dismiss() } label: { Label("開始倒數", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: 48) }
                    .buttonStyle(.plain).foregroundStyle(.white).background(Color(red: 0.08, green: 0.48, blue: 0.25), in: RoundedRectangle(cornerRadius: 14)).disabled(!(1...limit).contains(amount))
            }
        }.padding(20).frame(minWidth: 300, idealHeight: selectedChoice == -1 ? 590 : 480).themedSheet()
            .presentationDetents(selectedChoice == -1 ? [.height(590), .large] : [.height(480), .large])
    }
}

struct FeedbackEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ViewState private var text = ""
    @ViewState private var subject = "Music Player 意見反饋"
    @ViewState private var mail = false
    @ViewState private var error: String?
    private var environmentSummary: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return "System: \(ProcessInfo.processInfo.operatingSystemVersionString)\nMusic Player version: \(version)"
    }
    private var report: String { text + "\n\n" + environmentSummary }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("收件人：admin@monstrai.com").foregroundStyle(OrcaTheme.cyan)
                Divider()
                TextField("標題", text: $subject).textFieldStyle(.roundedBorder).accessibilityLabel("反饋郵件標題")
                TextEditor(text: $text).accessibilityLabel("反饋內容").frame(minHeight: 160).scrollContentBackground(.hidden)
                Text(environmentSummary).font(.caption).foregroundStyle(OrcaTheme.muted)
                if let error { Text(error).font(.caption).foregroundStyle(.orange) }
                ShareLink(item: report) { Label("另存或分享反饋", systemImage: "square.and.arrow.up") }
            }.padding(20).navigationTitle("Music Player")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button { compose() } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }.accessibilityLabel("撰寫郵件至admin@monstrai.com").disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
        }.frame(minWidth: 300, minHeight: 400).themedSheet()
        #if os(iOS)
        .sheet(isPresented: $mail) { FeedbackMailComposer(subject: subject, body: report) { result in mail = false; error = result } }
        #endif
    }
    private func compose() {
        #if os(iOS)
        if MFMailComposeViewController.canSendMail() { mail = true; return }
        #endif
        var url = URLComponents(); url.scheme = "mailto"; url.path = "admin@monstrai.com"
        url.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: report)]
        guard let link = url.url else { return }
        openURL(link) { accepted in if !accepted { error = "尚未設定郵件App。請先設定帳號，或另存反饋後寄至admin@monstrai.com。" } }
    }
}
#if os(iOS)
import MessageUI
struct FeedbackMailComposer: UIViewControllerRepresentable {
    let subject: String
    let body: String
    let completion: (String?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.setToRecipients(["admin@monstrai.com"]); controller.setSubject(subject); controller.setMessageBody(body, isHTML: false)
        controller.mailComposeDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let completion: (String?) -> Void
        init(completion: @escaping (String?) -> Void) { self.completion = completion }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            completion(error?.localizedDescription ?? (result == .failed ? "郵件無法送出，請稍後重試。" : nil))
        }
    }
}
#endif

struct PrivacyDetails: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("隱私政策 · 本機測試版").font(.title2)
                    Text("更新日期：2026年10月26日")
                    Text("音樂與使用資料").font(.headline)
                    Text("匯入的音樂會複製到App曲庫。歌名、歌手、頭貼、播放清單、收藏、評分、聆聽次數與音效偏好儲存在裝置上，用來提供播放與分類功能。")
                    Text("傳送與分享").font(.headline)
                    Text("目前App沒有內建帳號、廣告或第三方分析SDK，不主動將曲庫、評分或聆聽紀錄傳送給開發者。反饋郵件預設寄至admin@monstrai.com，包含你輸入的內容、作業系統與App版本；你在郵件畫面確認寄出後才會傳送。另存／分享由你選擇的服務處理。")
                    Text("管理資料").font(.headline)
                    Text("你可以在App內移除清單關聯、刪除App曲庫音檔或清除評分。刪除App內音檔不會刪除外部原始檔案；裝置、iCloud及電腦備份由系統與你所選服務管理。")
                    Text("本政策描述目前測試版的實際功能；若未來加入雲端、帳號或分析服務，會更新說明。可透過反饋頁寄信至admin@monstrai.com提出資料相關問題。")
                }.frame(maxWidth: 600, alignment: .leading).padding(20)
            }.navigationTitle("隱私政策")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.frame(minWidth: 300, minHeight: 400)
    }
}
