# iPhone 安裝紀錄

2026-10-24｜產品版本 v0.3.0｜使用者已授權安裝至連線的個人 iPhone。

英文需求對照：“My phone is already connected by cable. Please install the app onto it.”

## 已完成

- Xcode 已辨識實體 iPhone，系統版本顯示 iOS 27.0；已選取 `OrcaPlayer-iOS`，不使用 iPhone Simulator 作為安裝目標。
- 使用 Xcode 中既有的 Personal Team，設定自動簽章及 Apple Development 憑證。
- 透過 Xcode 執行真機建置與安裝流程。啟動階段收到手機未信任開發者 App 憑證的明確錯誤。
- 本機團隊 ID 保存於忽略版控的 `apps/apple/Signing.local.json`，產生器重建 iOS target 時會保留此設定；不將 Apple 帳號、裝置識別碼或憑證私鑰加入日誌。

## v0.3 安裝當時狀態：等待手機信任憑證

Xcode 回報：“The application could not be launched because the Developer App Certificate is not trusted.”

需由使用者在手機「設定 → 一般 → VPN 與裝置管理」選取本人 Apple 帳號的開發者 App，完成信任後，再由 Xcode 啟動。未取得可確認的成功啟動畫面／狀態前，不標示手機啟動或真機音訊驗收完成。

命令列 CoreDeviceService 在目前環境初始化逾時，因此改用 Xcode 原生介面進行安裝。這不影響 Xcode 已辨識手機與完成簽章設定的觀察。


## v0.4 更新結果（2026-10-24）

英文需求對照：“Please update the app on my phone.”

- 使用者再次明確授權更新至已連線的個人 iPhone；沿用相同 App 識別碼與既有自動簽章，沒有刪除 App 或重置資料。
- Xcode 選取 `OrcaPlayer-iOS` 與實體 iPhone，執行建置／安裝／啟動。最終活動狀態顯示 `Running OrcaPlayer on … iPhone`，此輪未再出現未信任憑證錯誤。
- 對照 Xcode 真機建置產物：`CFBundleShortVersionString = 0.4.0`、`CFBundleVersion = 4`，含 v0.4 音效與車輛設定日誌。
- 已完成手機安裝與啟動確認；尚未操作手機端所有功能、背景播放或 Fiesta 藍牙實車測試。此紀錄不能視為完整真機音訊驗收。
- 將本次更新結果同步到互動流程圖與原生日誌資源，並重新建置更新，讓手機上的開發日誌包含本筆紀錄。


## v0.4.1 更新結果（2026-10-24）

依使用者新要求移除座位距離與延遲參考，沿用原 App 識別碼更新。真機產物為 0.4.1／5，內含最新「簡化車輛設定」日誌。首次啟動出現 debugger attach 找不到行程，重試後 Xcode 顯示實體 iPhone 的活躍 App 行程與 Running 狀態，已確認啟動。沒有刪除 App 或重置音樂庫；舊距離欄位讀取相容性測試通過。實車藍牙與完整音訊驗收仍待完成。


## v0.5.0 更新結果（2026-10-24）

本輪音量改善第一階段隨專案延續手機更新。Xcode 真機建置 0.5.0／6，原生日誌與 canonical JSON 一致；Xcode 顯示 Running，已確認安裝與啟動。採合成頻率響應估算餘裕，尚無響度補償或限制器。初次聽測先降低播放音量，因本輪刻意減少舊版的過度衰減。Mac 原生 PCM 交叉驗證不等於 Fiesta 藍牙實車驗收。


## v0.6.0 更新結果（2026-10-24）

沿用原 App 識別碼，Xcode 建置／更新並顯示實體 iPhone 的 Running 狀態。真機產物版本 0.6.0／7，內含最新七段 EQ 與模式管理日誌。7 段及 1⅓ 倍頻程已經原生 PCM 驗證；手機的滑動展開手勢、完整功能與實車聽感仍待試用。設定首次轉換前由 App 保留原始偏好備份；沒有刪除 App 或重置音樂庫。


## 2026-10-26｜v0.7.0／9 實體iPhone更新

由搬移後的 projects/music-player/apps/apple/OrcaPlayer.xcodeproj 執行 Clean Build Folder，選擇 OrcaPlayer-iOS／已連接iPhone，Run完成後Xcode顯示Running與程序。核對簽章產物版本0.7.0／9、canonical開發日誌一致且無3份已撤除試音WAV。

已確認安裝與程序啟動，啟動程式含舊車輛欄位清理；未從手機容器直接讀取UserDefaults，因此不冒稱已逐項讀回清理結果。播放、背景定時與藍牙操作仍需實機驗收。控制台出現AURemoteIO初始化診斷，沒有以此證明實際音訊播放通過。

## V14／2026-10-30／0.21.0 build31

CoreDevice原位安裝成功，已安裝App清單讀回0.21.0／31。啟動遭SpringBoard `Locked`拒絕，已請使用者解鎖，尚未確認Running。安裝前後曲庫manifest逐位元相同（1229筆匯入＋內建曲目共1230首），音效偏好與17筆綁定語意相同，不刪App。完整測試／手機後續／備份見[V14驗收](V14低音與七段EQ實作驗收.md)。
