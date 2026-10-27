# v0.14.1／build19 音訊 Session 與鎖屏封面修復

2026-10-28。使用者提供 Xcode 的 AVAudioSession Hang Risk 截圖，要求解決。保留既有 App 識別碼、曲庫、播放清單與設定。

## 已確認的兩個問題

1. NativeAudioPlayer 是 MainActor 類別；舊 load 與 play 各呼叫一次 prepareSession，setCategory／setPreferredIOBufferDuration／setActive 在主執行緒執行。Xcode 明確警告可能造成介面無回應。
2. 在仍暫停的 iPhone 程序 PID81872，展開 Debug Navigator 的完整堆疊，Thread10 位於 `com.apple.MediaPlayer.MPNowPlayingInfoCenter/accessQueue`。呼叫鏈為 `_dispatch_assert_queue_fail → dispatch_assert_queue → _swift_task_checkIsolatedSwift → closure #2 in closure #1 in PlayerModel.refreshNowPlayingArtwork() → MPMediaItemArtwork jpegDataWithSize:`。封面 requestHandler 繼承 MainActor，系統從背景佇列呼叫時觸發執行緒斷言。這與 Session 警告是不同問題。

## 處理方式與原因

- 新增 prepareForPlayback 非同步準備階段。iOS 的 Session 操作集中在專用序列佇列 `com.orca.player.session`，不使用主執行緒同步等待。準備成功後才回到 MainActor 載入音檔、連接引擎並播放；load／play 不再各自啟動 Session。
- 每次明確開始／恢復播放仍會在該佇列重新啟用 Session，避免中斷後錯誤沿用「已啟用」狀態。I/O buffer 偏好在首次成功準備前設定；實際值由系統決定，不保證46ms。
- 使用唯一請求 ID，切換歌曲、取消準備、系統中斷與睡眠到期會使舊回覆失效。準備失敗會回報錯誤；快速下一首保留播放意圖，只有最後請求能啟動歌曲。取消不會強行中止已進行的系統啟用呼叫，但其回覆不能重啟播放。
- 鎖屏封面回呼明確標示 `@Sendable`，只回傳已準備好的不可變 UIImage，不讀 UI 或模型狀態。圖片解碼與模型更新維持原有隔離。
- 保留 Swift actor 檢查與 Xcode 診斷；沒有關閉警告或並行保護。

新 SDK 的 async activate API 於 iOS27 起提供（本機 Xcode iPhoneOS SDK 的 AVAudioSession.h），專案最低 iOS17，因此採可向下相容的序列背景佇列。該 SDK 同時提供同步 setActive，並不代表應在 MainActor 呼叫它。

## 驗收與範圍

- `scripts/check_audio.py`：背景 Session worker／MainActor 回覆、設定失敗重試、取消／切歌／中斷／定時／錯誤／最後請求測試，以及原有曲庫、播放、計次、EQ、遷移回歸通過。
- iOS Simulator generic target（arm64／x86_64）編譯通過；環境 CoreSimulator 服務不可用，未宣稱已在模擬器執行。
- macOS Debug 編譯通過；互動流程25節點／30筆版本／83項改動及原生日誌副本一致，JavaScript語法檢查通過。
- 這次修正了明確的主執行緒 Session 呼叫與已取得堆疊的封面斷言。先前「操作時雜音」仍需手機／藍牙重現與聽測，不能由編譯或模型測試推論全部消除。

## 手機與交付紀錄

最後修正亦使刪除目前歌曲先取消待完成的播放準備，避免等待檔案刪除時舊請求啟動。完整模型回歸再次通過，iOS與macOS最後來源再次編譯通過。

Xcode 已替換舊程序並安裝 v0.14.1／19，最後程序 PID82043 顯示 Running（觀察27.8MB）；裝置建置產物的 Info.plist 與日誌副本核對一致。此為安裝／啟動證據，不等於已完成手機播放、鎖屏／中斷及藍牙聽測。

`deliverables/OrcaPlayer.app` 與 `MusicPlayer-macOS-0.14.1.zip` 為本輪 macOS Debug 產物，未公證；iPhone 仍透過 Xcode 本機開發簽章安裝。使用者音樂與原有資料未刪除。

備份依專案長期要求提交與推送，遠端 SHA 核對後才回報成功；本輪離線 bundle 存於忽略目錄 `backups/local/`。
