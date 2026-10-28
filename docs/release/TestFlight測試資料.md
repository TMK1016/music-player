# Music Player — TestFlight 測試資料

以下為可貼入 App Store Connect 的草稿，尚未提交。

## Beta App Description（繁體中文）
Music Player 是 iPhone／iPad 本機離線音樂播放器。從「檔案」匯入你有權使用的音訊，管理播放清單、歌手、收藏與五星評分，並在播放頁調整七段等化器、低音增強及音效模式。支援背景播放、系統媒體控制與睡眠倒數。App 不需註冊帳號。

## What to Test（繁體中文）
1. 從首頁匯入音訊，確認離線播放、播放清單與歌曲資訊編輯正常。
2. 測試切換首頁／正在播放／設定及千首曲庫的搜尋、排序和滑動速度。
3. 播放時切換 App、鎖定螢幕，確認背景播放及鎖屏控制；接上藍牙耳機或車機後測試切歌與重新連線。
4. 一邊播放一邊開關工具抽屜、換封面與調整七段 EQ／低音，留意雜音、爆音、中斷及介面卡頓。先以低音量測試，避免大幅提高多個頻段。
5. 測試分鐘／歌曲倒數、收藏、評分、自訂模式與重新啟動後的保存。
6. iPad 請特別檢查橫直向、視窗大小變化與 EQ 是否完整顯示。

回報請包含裝置型號、系統與 App 版本、連接方式、重現步驟及發生時間。可從 TestFlight 傳送回饋，或使用 App「設定 → 反饋」。請勿附上無權分享的音樂檔案。

## Review Notes（English）
No login or review credentials are required. This is a local audio player with no subscriptions, advertising, in-app purchases, or music-download service. Use the bundled original soundcheck audio, or import an authorized local audio file through Home's import control. Open Now Playing, swipe the album artwork left or tap the sound-profile label to access the seven-band equalizer and bass control. Background audio is used for ongoing music playback. The speaker control opens Apple's audio-output route picker; Bluetooth is an output route, not a music catalog or incoming audio source. No vehicle-specific DSP, per-speaker calibration, Dolby certification, or YouTube download functionality is claimed.

## 欄位與待補資訊

- 回饋電子郵件：admin@monstrai.com（使用者已指定）。
- Beta 審核聯絡人姓名／電話／電子郵件：須使用帳號已有的有效資料或由使用者提供；不代填假資料。
- 隱私政策網址：尚未建立可對外存取網址；App 內已有本機測試版說明。若平台要求網址，先部署與實際行為一致的政策頁。
- 發佈群組：建議先小範圍外部測試；尚未建立群組、發送邀請或產生邀請連結。
- 最低系統：iOS／iPadOS 17.0；iPad 真機體驗尚未驗收。
- 已知限制：實際藍牙／操作雜音與長時間播放仍須封測驗證；不能宣稱全部消除。

## 測試者安裝說明（核准並取得連結後使用）

在 iPhone 或 iPad 的 App Store 安裝 Apple TestFlight，開啟我們提供的邀請連結，再按接受與安裝。測試版有期限，後續在 TestFlight 更新。測試資料請另留原始檔；移除 App 可能移除 App 曲庫副本。現階段尚無可提供的邀請連結。
