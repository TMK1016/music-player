# Music Player 本機播放器 v0.6

首頁側邊欄新增「開發日誌」。點選改動會展開節點與檔案位置；有對應功能頁的項目可直接前往播放、音樂庫、等化器或車輛設定。紀錄由 `planning/changelog.json` 共用產生，每次更新需同步，詳見[開發日誌與更新流程](../../docs/zh-TW/開發日誌與更新流程.md)。

在 Xcode 開啟 `OrcaPlayer.xcodeproj`，選 `OrcaPlayer-macOS` → `My Mac` → `⌘R`。

iOS target 已通過 generic Simulator 編譯；手機實際執行、背景播放與 CarPlay 尚未驗證。

## 開始使用

1. 播放內附的 `ORCA Soundcheck` 原創測試片段，確認輸出。
2. 到「音樂庫」按「匯入音樂」，可一次選取多個本機音檔。
3. 點選曲目開始播放；支援暫停、定位、切歌、順序／隨機／整份循環。
4. 到「等化器」調整 7 段增益、13 預設、低音增強與空間殘響；可儲存最多 20 組命名模式並綁定歌曲。
5. 到「車輛設定」選前後喇叭類型、座位預覽與聲道試音。v0.4.1 已移除座位距離與延遲參考。

[音效與車輛完整說明](../../docs/zh-TW/音效模式與車輛調音.md)／[v0.4 驗收](../../docs/zh-TW/音效模式驗收.md)。

原始檔會保留，App 使用自己的離線副本；同內容不同檔名也會去重。資料位於系統 Application Support 的 `OrcaPlayer/Library/`。損毀索引不會被自動覆寫。WAV 已有明確驗收，其他格式經系統逐檔解碼驗證，尚無完整格式矩陣。

EQ 已真正處理本 App 的音訊。前級以 EQ／低架合成頻率響應最高正增益加 3 dB、有效殘響預留量保留餘裕（衰減上限 96 dB）；旁通會停用濾波並保留補償。它不是限幅器、量測響應或已校正的逐喇叭 DSP。曲目標題目前採來源檔名；自訂命名歌單、專輯標籤、iCloud 自動同步與第三方下載仍待完成。

Rust 核心尚未接入；目前以 `AudioPlayback` 協定隔離 Apple 原生音訊參考後端。

## 建置

最低部署設定為 macOS 14／iOS 17，尚非正式相容性承諾。沒有外部套件或網路依賴。在 `projects/music-player` 執行：

```sh
python3 scripts/generate_demo_audio.py
python3 scripts/generate_channel_checks.py
python3 scripts/generate_xcode_project.py
xcodebuild -project apps/apple/OrcaPlayer.xcodeproj -scheme OrcaPlayer-macOS -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath apps/apple/.build CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64 build
python3 scripts/check_audio.py
```

檢查腳本執行隔離的匯入／播放狀態測試，並產生 `apps/apple/.build/checks/NativeEQValidation.app`。用 Finder 開啟該 App 可驗證原生離線 PCM，不會出喇叭；結果寫入 `.build/checks/native-eq-result.txt`。

產生器會重建 target／scheme；Xcode 設定變更需同步回產生器。此版本為本機開發建置，未公證或上架。

完整證據與限制見 [本機音訊實作與驗收](../../docs/zh-TW/本機音訊實作與驗收.md)。

[EQ 音量處理技術與驗收](../../docs/zh-TW/EQ音量處理技術.md)：v0.5 第一階段；響度補償與限制器尚未加入。

[v0.6 七段 EQ 與模式管理](../../docs/zh-TW/七段等化器與模式管理.md)：模式列右上新增自訂，長按或完整選單管理，舊設定保留備份並轉換為 v3。
