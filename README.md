**v0.9.0 三頁細節與單頁調音**：[本輪規格、驗收與手機交付](docs/zh-TW/三頁細節與單頁調音-v09.md)。

# Music Player

[播放頁原位調音改版](docs/zh-TW/播放頁滑動調音改版.md)／[設計來源](DESIGN.md)：v0.8依使用者參考稿調整，實作與驗收狀態分開記錄。

最新修復：[v0.7.1音訊回呼崩潰](docs/zh-TW/v0.7.1音訊回呼崩潰修復.md)；設定頁可核對版本／build。

車用離線音樂播放器與 DSP 規劃。更新：2026-10-24。

[專案主筆記（Obsidian 編輯入口）](notes/專案主筆記.md)

[Mac v0.7.0 開發包](deliverables/MusicPlayer-macOS-0.7.0.zip)

**v0.7.0 開始實作三頁曲庫、50%背景歌曲格、底部迷你播放器及聆聽限制。** [實作與限制](docs/zh-TW/三頁曲庫與定時實作.md)。車輛設定及試音已依新要求撤除。尚未宣稱全部UIUX或真機驗收完成。

[2026-10-26 功能與UIUX規格](docs/product/UIUX-首頁與播放體驗.md)（規劃，尚未改版）

**PM 管理入口**：[產品需求基準](docs/product/PRD-music-player.md)／[流程與驗收](docs/product/PM流程與驗收.md)／[互動 PM 與工程圖](planning/flow-inspector.html)／[任務來源](planning/pm-plan.json)

**v0.6.1 模式改為橫欄下方原位展開，手動調整滑桿後提供「儲存新模式」。v0.6 改為合理分佈的 7 段 EQ，七欄完整適配螢幕；模式改為單列／完整選單，支援自訂新增、移除與舊資料轉換。保留合成響應餘裕，未加入響度補償或限制器。**

- [Mac v0.6.1 開發包](deliverables/OrcaPlayer-macOS-0.6.1-inline-modes.zip)
- [模式內嵌展開與儲存提示](docs/zh-TW/模式內嵌展開與儲存提示.md)／[英文需求](docs/en/inline-modes-save-prompt-requirements.md)
- [七段 EQ 與模式管理](docs/zh-TW/七段等化器與模式管理.md)／[完整英文需求](docs/en/seven-band-eq-requirements.md)
- [Mac v0.6 開發包](deliverables/OrcaPlayer-macOS-0.6-seven-band.zip)

- [直接開啟 EQ 技術區塊](planning/flow-inspector.html#section=eq-technical)
- [EQ 技術與驗收](docs/zh-TW/EQ音量處理技術.md)／[英文需求](docs/en/eq-technical-and-headroom-requirements.md)
- [Mac v0.5 開發包](deliverables/OrcaPlayer-macOS-0.5-eq-headroom.zip)

- [v0.4.1 車輛設定簡化](docs/zh-TW/車輛設定簡化.md)
- [Mac v0.4.1 開發包](deliverables/OrcaPlayer-macOS-0.4.1-simplified-vehicle.zip)
- [音效模式與車輛調音](docs/zh-TW/音效模式與車輛調音.md)／[本次驗收](docs/zh-TW/音效模式驗收.md)／[英文需求](docs/en/sound-profiles-and-vehicle-requirements.md)
- [Mac v0.4 開發包](deliverables/OrcaPlayer-macOS-0.4-sound-profiles.zip)：歷史開發包，未公證／上架，v0.4 已另透過 Xcode 更新並啟動於連線 iPhone；實車驗證仍待完成。

- [開發日誌與更新流程](docs/zh-TW/開發日誌與更新流程.md)
- [日誌資料來源](planning/changelog.json)：23 階段、55 項改動，與 App 共用。
- [本次需求英文翻譯](docs/en/development-journal-requirements.md)
- [Mac v0.3 開發日誌版本](deliverables/OrcaPlayer-macOS-0.3-development-log.zip)：歷史開發包，首頁側邊欄包含開發日誌。

- [本機音訊實作與驗收](docs/zh-TW/本機音訊實作與驗收.md)
- [本輪需求英文翻譯](docs/en/local-audio-requirements.md)
- [Mac v0.2 本機播放開發包](deliverables/OrcaPlayer-macOS-0.2-local-audio.zip)：解壓縮後執行；本機開發建置，未公證／上架。

- [Xcode 原生介面專案](apps/apple/OrcaPlayer.xcodeproj)：`OrcaPlayer-macOS`／`My Mac`／`⌘R`。
- [介面操作與建置說明](apps/apple/README.md)
- [介面實作與驗收](docs/zh-TW/介面實作與驗收.md)
- [本次介面需求英文翻譯](docs/en/interface-requirements.md)

- [需求與完整開發路徑](docs/zh-TW/需求與開發路徑.md)
- [完整英文需求翻譯](docs/en/original-requirements.md)
- [官方來源與查證記錄](docs/zh-TW/來源與查證.md)
- [待確認決策](docs/zh-TW/決策紀錄.md)
- [互動流程檢視器](planning/flow-inspector.html)：用瀏覽器開啟，可選節點查看任務、依賴、驗收與預計實作路徑。
- [流程資料來源](planning/flow.json)：節點 ID、依賴與狀態的可修改來源。

## 維護流程圖

每次更新同步修改 `planning/changelog.json` 與對應的 `planning/flow.json`；先執行 `python3 scripts/generate_xcode_project.py` 同步 App 日誌，再執行 `python3 planning/build_inspector.py` 及 `python3 planning/validate_plan.py`。檢查涵蓋依賴、改動／節點／實作檔案、HTML 與 App 日誌一致性。詳見更新流程文件。檢視器不依賴網路、套件或伺服器。

檢視器為手動維護的規劃與證據視圖，沒有接入執行事件。本機音訊相關節點標示「部分實作」，不是整個 Rust／車用節點完成。後續 FLOW-01 才會建立自動事件整合。

## 暫定技術方向

Rust 2024 edition 預計負責後續 DSP 與共用邏輯；目前採 SwiftUI＋AVAudioEngine／AVAudioUnitEQ 建立可驗證參考後端，未安裝 Rust 編譯器。已確認 Mac M2／Xcode 開發與打包；實際車用播放端尚未凍結。

## 下一個可執行里程碑

下一步補完整格式矩陣、長時間連播與裝置切換；確認車用播放端後進行真機／實車驗證。Rust DSP spike 仍需工具鏈與橋接，不以原生 EQ 取代該驗收。雲端與第三方下載另有來源能力與授權前提。

- [流程圖縮放與節點註解](docs/zh-TW/流程圖縮放與節點註解.md)：圖面縮放、節點修改需求、JSON 備份與交辦。

專案位置：`projects/music-player/`；上層 Orca 為整合工作區。[檔案分類與更名說明](docs/zh-TW/專案更名與檔案分類.md)。

最新本機測試版：[MusicPlayer-macOS-0.8.0.zip](deliverables/MusicPlayer-macOS-0.8.0.zip)。macOS／iOS編譯及模型檢查通過；已查看macOS封面／EQ原生畫面，iPhone觸控驗收仍待完成。

2026-10-26 手機已透過Xcode更新至0.8.0／build 11，啟動後觀察到signal 9終止，持續運行待釐清；[部署結果與限制](docs/zh-TW/v0.8手機部署.md)。完整觸控與音訊驗收仍待完成。

最新本機測試封裝：[MusicPlayer-macOS-0.9.0.zip](deliverables/MusicPlayer-macOS-0.9.0.zip)。手機已由Xcode更新至0.9.0／build 12並觀察到Running；本輪實際證據與仍待驗收項目見v0.9文件。
