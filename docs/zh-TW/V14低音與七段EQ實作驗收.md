# V14：低音與七段 EQ 實作、驗收

2026-10-30，0.21.0／build31。節點 EQ-01、PROFILE-01、QA-01、IOS-01、QA-02、RELEASE-01；[完整英文需求](../en/v14-requirements.md)。採 project-pm／identify-assumptions-existing／test-scenarios、linear-dev-orchestrator，以及 Orca CLI 的一次性自動化管理。使用者筆記原文保留。

## 啟動與實際基準

先讀取工具時間：2026-10-29 18:00:51 UTC，臺北已是10月30日02:00:51，才開始實作。同名自動化已設為 disabled，不中斷本輪。基準提交 `4b40b3555869d60be6f4ac984c62c96ca4fb344c`；開始時只有使用者 V14 筆記已有未提交修改，保留並隨需求備份。

V13-A 原生矩陣重新執行，[開始前報告](../verification/V14-before-native.txt)。整曲分析確實完成，不是只停在fallback。另重新重現稀疏40Hz低頻尖峰：`peakLimited=true`、單一前級 **−9.532941 dB**、bass-off參考−3 dB、未衰減wet峰值估計+8.03294 dB。因此即使大多數時間只有普通中頻，短峰值仍會壓低整首。未分析前bass9的舊fallback更是−12 dB。以前的中頻−0.43 dB是相對另已衰減−3 dB的參考；不能解讀成相對真正原聲只少0.43 dB。

讀取手機目前偏好確認：七段平、EQ開啟、低音0、殘響關閉、單曲模式政策開啟、17筆歌曲綁定、無自訂模式。這份持久設定不保存分析是否完成，**不能從它追認使用者之前聽測時的分析狀態**，也未播放私人歌曲。程式稽核確認 `applyPreset` 與 `applySongBinding` 原先呼叫整份 `setSound`，內建模式bass0確實能覆寫獨立低音。

## 實際改動與取捨

```text
系統解碼／保留原取樣率
  → 輸入混音器（單聲道轉雙單聲道）
  → 七段 Apple EQ（前級0 dB）
  → 90Hz低架（獨立0～9；約80ms增益漸變）
  → 既有可選殘響
  → Apple Peak Limiter（0 dB pregain；attack3ms／decay60ms）
  → 單一−1dB輸出預留
  → 使用者App音量 → 系統／藍牙輸出
```

`AudioPlayback.swift`、`PeakControl.swift` 是正式路徑。取消播放端的整曲分析、300ms等待及分析結果套用；`BassAnalysis.swift`／`EQHeadroom.swift` 保留作歷史參考、原生對照及估算研究，**不再是播放fallback**。前級明確指定0，不先寫入舊headroom再覆寫，沒有把多份補償／殘響預留疊加。Limiter是動態非線性處理，並非透明等響器或硬削波器；在持續超載時仍會衰減整段。−1dB是明列的單份重建預留，不依低音值加重，未稱認證true-peak上限。

七段保留50／125／315／800／2k／5k／12.5k Hz、約1⅓倍頻程、±12dB及高於0.45×取樣率的旁通。130個Apple實際PCM探測點的最大模型誤差0.033dB，最大低估0.016dB，沒有證據支持任意改濾波公式或加FFT就會提升解析度。改善的是輸入聲道正規化、增益政策與參數更新：EQ與低音用16×5ms控制漸變，快速操作取消前一段並從實際中間值延續；音量／相同設定不重建圖、不重啟分析。這是控制層分步平滑，沒有宣稱所有AU參數sample-accurate。播放render由Apple擁有，沒有加入自訂回呼、檔案分析、鎖或日誌；量測器只在驗證工具執行。

模式與歌曲綁定只套EQ／殘響，保留當前獨立低音；返回未綁定歌曲亦保留後來手動調的低音。存檔時即使正使用單曲EQ，也保存最新全域低音。模式名稱比對排除獨立低音，因此搖滾＋低音3仍顯示「搖滾」。舊v1/v2/v3、模式ID、名稱、綁定及模式內歷史bass欄位仍能讀取，選取不強制套用舊bass快照。明確「重設」或EQ主開關關閉仍依V9回到原聲（包括低音0）；這是既有明確還原行為。

## 第一手來源與工程假設（2026-10-30查證）

- [Apple Peak Limiter parameters](https://developer.apple.com/documentation/audiotoolbox/1389597-peak_limiter_unit_parameters) 與本機Xcode27 SDK `AudioUnitParameters.h`：attack範圍1～30ms、decay1～60ms、pregain−40～40dB。本版3／60ms與−1dB預留是工程選擇，不冒稱Apple建議預設或公開其內部偵測器設計。左右連動另以不對稱PCM驗證。
- [W3C Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/)：參數濾波／低架與數位頻寬校正作估算參考；Apple實際響應另測。
- [MathWorks Psychoacoustic Bass Enhancement](https://www.mathworks.com/help/audio/ug/psychoacoustic-bass-enhancement-for-band-limited-signals.html)：示範分頻、低頻諧波產生、帶通及混合，針對頻寬受限喇叭且截止依喇叭條件選擇。本版沒有外接DSP或單體回授，沒有喇叭截止量測；新增諧波會引入音色與互調風險，故本次未選用，也沒有以強制削波增加「低音感」。

工程假設：一般混合音訊的低架真實增幅，加上只在峰值需要時介入的動態控制，可比整曲固定衰減更符合主要音量接近原本的目標。密集低頻主導／強EQ不能同時保證原樣中頻、完整提升、零失真及不超過輸出上限。數位峰值不保證藍牙編碼、車機、功放、喇叭都不失真；沒有實車聽感保證。

## 原生PCM結果

[完整報告](../verification/V14-native-result.txt)／[新路徑CSV](../verification/V14-native-pcm.csv)。訊號自製合成，不使用私人媒體。比較基準為相同未衰減原始輸出（EQ主關，前級0、無預留），另量測啟用bass0；不是同一份靜態補償的旁通冒稱改善。

44.1／48／96kHz三取樣率結果一致，以下為48kHz普通混合訊號：

| 低音值 | 40Hz相對真原聲 | 1kHz相對真原聲 | 整體響度差 |
|---|---:|---:|---:|
| 0 | −1.000dB | −1.000dB | −0.999LU |
| 3 | +1.885dB | −1.000dB | −0.849LU |
| 6 | +4.759dB | −1.000dB | −0.573LU |
| 9 | +7.607dB | −0.999dB | −0.088LU |

相對啟用bass0，低音3／6／9增加2.885／5.759／8.607dB。搖滾＋低音3相對相同搖滾bass0另增加**2.885dB**。比起A的低音6，實際未衰減原聲比較的低頻由約2.34dB提高到4.76dB；這是特定合成條件，不是所有歌曲的通用改善量。

壓力測試（48kHz）：密集低頻、原始峰值接近滿幅時，bass3／6／9的低頻仍分別增加1.552／2.951／4.162dB，但中頻下降1.328／2.792／4.420dB，整體響度差−0.985／−1.857／−2.540LU；估計輸出峰值約−1dB。這是限制器持續作用的實際代價，未列為等響通過。稀疏尖峰的非尖峰中頻約−1dB，沒有A的整曲−9.53dB；脈衝期間低頻增量有限，詳CSV，不能隱藏。

不對稱左聲道低頻尖峰、兩側同時1kHz探針時，探針左右差−0.153dB，支持此測試條件的連動衰減。40Hz低電平正弦bass9的2～20次THD約0.0000008%；故未主動生成可觀諧波。故意超載的40Hz測試THD **0.406%**、估計峰值−1.001dB，不能稱限制器零失真或硬體保護保證。強EQ正負交錯、全+12、低音9、room混合35、尾音、靜音、16kHz單聲道均通過有限值／峰值或聲道幅度檢查。

M2原生離線1024frame呼叫，在這次普通訊號矩陣最大約0.207ms，p99約0.114～0.127ms；96kHz每塊預算10.67ms。這只量測`renderOffline`呼叫，排除離線量測／檔案／UI成本；不是iPhone即時callback p99或整機CPU保證。量測未加到正式播放render／主執行緒。

## 行為及交付證據

模型驗收包含搖滾＋低音3名稱／後端疊加、跨內建／自訂模式、綁定及未綁定歌曲往返、綁定中改低音再存檔重啟、舊模式bass快照保存、v1/v2/v3轉換及既有曲庫／播放政策。Native整合確認實際AU最後參數是搖滾七段＋bass3＋前級0；60次快速配置／seek／load沒有過期分析覆寫。另用自製8秒音訊、最終App音量0實際驅動Mac音訊裝置，在驗證App隱藏時進度繼續；40次播放中EQ／低音操作、暫停、重新載入播放、seek至尾端與單次自然完成通過。沒有打開私人歌或在喇叭播放驗證音。

雙平台Debug建置與模型／原生PCM通過。iOS背景audio宣告、非主執行緒session啟用、既有中斷策略保留；**Mac隱藏驗證不等於iPhone鎖屏／藍牙／實車60分鐘驗收**，這些持續列待實機聽測，不捏造已通過。

### 手機與來源包

CoreDevice原位安裝成功；直接讀取已安裝App清單為 **0.21.0／31**、相容bundle ID不變。啟動請求被SpringBoard明確以 `Locked / FBSOpenApplicationErrorDomain 7` 拒絕，已請使用者解鎖；**尚未確認Running**，不能把安裝成功寫成啟動成功。

安裝前後直接讀取手機manifest逐位元相同，SHA-256 `9e47007ae5d9ca29845dec5ac0a3faf2c26df4002b1624f04c208f2ed3adbef2`；1229筆匯入歌曲，加內建Soundcheck共1230首。音效偏好語意完全相同，17筆歌曲綁定保存；沒有刪App、私人檔案或清空資料。只讀取本次保存核對所需的索引／偏好，私人內容與裝置識別留在本機，不納入Git。

朋友來源包 `deliverables/MusicPlayer-0.21.0-build31-Friend-Source.zip`：48個白名單檔案、36份Swift來源；ZIP完整性與每檔SHA-256 manifest驗證通過，不含簽章帳號、憑證、私人媒體與可重建快取。包SHA-256 `ce9457d6c51f5e1acf0634fd8257007226ed4bb51b727c235d2a62ccae80f679`。

### Git備份

核心實作提交 `41240036c9f9768fb58a65c23af297ce3b7cfae8` 已推送至既有私人GitHub `TMK1016/music-player` 的main，並以 `git ls-remote origin refs/heads/main` 核對相同SHA；沒有force push。另保存 `backups/local/music-player-v14-0.21.0-build31.bundle`，`git bundle verify`確認完整歷史可還原。交付紀錄的後續提交亦依同樣方式推送／核對，最後SHA保存於本機 `backups/local/v14-handoff.json`。遠端不含私人曲庫、手機偏好副本、簽章與憑證。
