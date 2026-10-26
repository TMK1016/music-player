import SwiftUI

struct DevelopmentJournal: Decodable {
    let entries: [JournalEntry]
    static var bundled: DevelopmentJournal? {
        guard let url = Bundle.main.url(forResource: "changelog", withExtension: "json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(DevelopmentJournal.self, from: data)
    }
}
struct JournalEntry: Decodable, Identifiable {
    let id: String
    let version: String
    let date: String
    let title: String
    let summary: String
    let changes: [JournalChange]
}
struct JournalChange: Decodable, Identifiable {
    let id: String
    let title: String
    let summary: String
    let nodeIds: [String]
    let targetPage: String?
    let locations: [JournalLocation]
    enum CodingKeys: String, CodingKey {
        case id, title, summary, locations
        case nodeIds = "node_ids", targetPage = "target_page"
    }
}
struct JournalLocation: Decodable {
    let path: String
    let label: String
}

struct DevelopmentLogView: View {
    @ObservedObject var model: PlayerModel
    private let journal = DevelopmentJournal.bundled
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "BUILT IN THE OPEN")
                Text("每次進步，都有跡可循。").font(.system(size: 25, weight: .semibold))
                Text("點選每筆改動，查看對應節點與檔案，或前往功能頁。")
                    .font(.system(size: 13)).foregroundStyle(OrcaTheme.muted)
            }
            if let journal {
                ForEach(journal.entries) { entry in
                    Panel(padding: 22) {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack { Tag(text: entry.version); Spacer(); Text(entry.date).font(.system(size: 11, design: .monospaced)).foregroundStyle(OrcaTheme.muted) }
                            Text(entry.title).font(.system(size: 20, weight: .semibold))
                            Text(entry.summary).font(.system(size: 12)).foregroundStyle(OrcaTheme.muted).fixedSize(horizontal: false, vertical: true)
                            ForEach(entry.changes) { change in changeRow(change) }
                        }
                    }
                }
            } else {
                Panel {
                    Text("開發日誌尚未載入，請確認安裝包包含 changelog.json。")
                        .foregroundStyle(OrcaTheme.muted)
                }
            }
            Text("日誌記錄各版本當時的範圍；不是音訊即時監控或所有功能完成的保證。")
                .font(.system(size: 11)).foregroundStyle(OrcaTheme.muted)
        }
    }
    @ViewBuilder private func changeRow(_ change: JournalChange) -> some View {
        let expanded = model.selectedLogChangeID == change.id
        VStack(alignment: .leading, spacing: 12) {
            Button {
                model.selectedLogChangeID = expanded ? nil : change.id
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(OrcaTheme.cyan).padding(.top, 4)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(change.title).font(.system(size: 14, weight: .medium)).foregroundStyle(OrcaTheme.text)
                        Text(change.summary).font(.system(size: 12)).foregroundStyle(OrcaTheme.muted).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel("\(expanded ? "收合" : "查看")改動：\(change.title)")
            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("對應節點 · " + change.nodeIds.joined(separator: " / "))
                        .font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(OrcaTheme.cyan)
                    ForEach(change.locations, id: \.path) { location in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.label).font(.system(size: 12, weight: .medium))
                            Text(location.path).font(.system(size: 11, design: .monospaced)).foregroundStyle(OrcaTheme.muted).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let destination = PlayerPage.destination(for: change.targetPage), destination != .developmentLog {
                        Button {
                            model.page = destination
                            model.driveMode = false
                        } label: {
                            Label("前往\(destination.rawValue)", systemImage: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(OrcaTheme.cyan)
                                .padding(.vertical, 9)
                        }.buttonStyle(.plain)
                    }
                }.padding(.leading, 23)
            }
        }.padding(15).background(expanded ? OrcaTheme.blue.opacity(0.1) : OrcaTheme.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}
