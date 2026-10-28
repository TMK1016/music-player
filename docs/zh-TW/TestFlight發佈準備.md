# Apple TestFlight 發佈準備

本輪沿用專案既有 docs／planning 分類，使用 PM shipping-artifacts 與 intended-vs-implemented 的交付核對方法。發佈準備不代表 Apple 已核准外部試用。

## 狀態

- 使用者授權先讓 Apple 用戶試用，維持 iPhone／iPad universal target 與既有 bundle ID。
- 手機仍是已安裝的 0.15.0／21；本輪準備 0.15.0／22，不刪除手機資料。
- 補入原創科技藍 App Icon、隱私 manifest。Release archive 已編譯成功；為未簽章的本機驗證封存，不能直接發給朋友安裝。簽章／Apple 上傳狀態另列。
- App Store Connect 已在 Chrome 開啟，尚待使用者登入；付費會員資格尚未確認。既有裝置 development provisioning profile 有效期 7 天，只能證明現有開發安裝，不能證明已付費。
- Beta 文案與操作清單：[測試資料](../release/TestFlight測試資料.md)。尚未填假聯絡資料、建立商店紀錄或公開邀請連結。

## 系統、資料與權限邊界

Native SwiftUI／AVFoundation，沒有第三方 SDK、後端帳號或 AI 功能。架構與現有測試對照沿用 [V8驗收](V8實作與架構驗收.md)、[音訊驗收](本機音訊實作與驗收.md) 與 [背景播放](背景播放與互動優化-v010.md)。

| 流程 | 授權與結果 | 實作位置 |
|---|---|---|
| 檔案匯入／資料夾搜尋 | 使用者經系統 picker 授權選取範圍，security scope 存取後複製；無法讀取時回報失敗；不擅自掃描整支手機 | ContentView.swift、LocalMusicSearch.swift、LibraryStore.swift、LibraryScan.swift |
| 頭貼／封面 | 使用者選圖後裁切，處理上限與背景縮圖；不自動上傳 | LibraryManagement.swift、ArtworkPipeline.swift |
| 刪除 | 區分移除清單關聯與刪除 App 副本；刪檔需確認，不刪外部來源 | MusicCollection.swift、LibraryStore.swift、MusicExperience.swift |
| 反饋與分享 | 由使用者確認系統郵件／分享畫面才傳送；無自動郵件服務 | ExperienceControls.swift |
| 背景播放 | iOS audio background mode 用於使用者正在播放的音樂；無背景追蹤或伺服器排程 | iOS-Info.plist、AudioPlayback.swift |
| TestFlight | 程式封存交 Apple；Apple 自身的測試診斷、當機與回饋處理不等於 App 自建分析 SDK | Apple TestFlight 官方說明 |

## 設定與必要 API 宣告

- Signing.local.json 與本機簽章帳號只存在本機且被 Git 排除；無 App 內 API key／服務憑證。無需新增服務端環境變數。
- UserDefaults 僅儲存 App 自身偏好，manifest 使用 CA92.1；systemUptime 用於 App 內經過時間與聆聽計數，使用 35F9.1。原始 uptime 不離開裝置。
- CryptoKit SHA256 僅用來去重，不是內容加密；出口合規答案仍須與 App Store Connect 的實際問題核對，不以未驗證的布林值跳過問卷。
- 沒有廣告、追蹤、第三方 analytics，manifest 的 collected-data 陣列為空；郵件由使用者自行選擇傳送，公開政策需交代 Apple TestFlight 自身診斷。
- 沒有 App 內代理、webhook、SEO 網站、伺服器排程或自動郵件，因此不產生虛構對應文件。

## 驗收及缺口

現有模型與 UI／音訊測試見 V8 驗收，不因素材調整宣稱重測過實際音響。此輪檢查 icon 不透明 1024px、asset catalog 編譯、manifest／日誌打包、Release archive 版本與裝置支援。待辦：distribution 簽章、Apple validation／upload、處理完成、外部審核、乾淨 iPhone／iPad 實測與邀請連結；其中任一未完成均不稱可供朋友安裝。

## 查證來源（2026-10-28）

- [TestFlight](https://developer.apple.com/testflight/)：外部群組與首個審核。
- [測試資訊](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/)：描述與回饋欄位。
- [上傳 builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)：帳號權限與處理流程；本機 Xcode 版本是否被接納以實際 validation 為準。
- [必要 API 使用原因](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)：UserDefaults／systemUptime。
- [加密出口說明](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)：系統加密與非豁免加密的區分。

## 本機重建與回復

執行 `zsh scripts/release/archive_ios.sh`，產生 `apps/apple/.build/testflight/MusicPlayer-0.15.0-22.xcarchive` 並核對內容。封存及 DerivedData 不進 Git；腳本、圖示來源與必要資源納入 Git。此輪沒有更動播放引擎，也沒有覆蓋手機 build21；需要回復時可取既有 build21 提交重建，維持 bundle ID 與曲庫路徑。不可用降低版本號的 App Store 上傳取代正常後續 build。

## 備份狀態

本輪 `git push origin main` 仍失敗：`Could not resolve host: github.com`。保留本機提交與 `backups/local/MusicPlayer-TestFlight-preparation.bundle` 全歷史備份；未核對遠端提交前不稱已同步。

最終驗證：`archive_ios.sh` 完成 ARCHIVE SUCCEEDED；`check_archive.py` 通過版本／device family／背景播放／圖示／manifest／示範音源與完整日誌一致性檢查。流程驗證通過 25 節點、36 階段、90 改動與 14 PM 項目，JavaScript 語法通過。沒有執行 Apple 雲端 validation 或 upload。
