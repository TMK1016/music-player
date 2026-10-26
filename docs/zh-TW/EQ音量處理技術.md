# EQ 音量處理技術與驗收 · v0.5.0

本頁保留 v0.5 的 10 段歷史設計與測試。v0.6 已改為 7 段及約 1⅓ 倍頻程，最新範圍與驗收見[七段等化器與模式管理](七段等化器與模式管理.md)。

2026-10-24。任務 EQ-01／QA-01／FLOW-01；使用者授權先加入互動技術說明，再一次實作一種音量改善方案。完整英文需求見 `docs/en/eq-technical-and-headroom-requirements.md`。

## 目標與範圍

修正 EQ 滑桿正增益累加所造成的過度衰減；不在本輪同時加入響度補償、限制器或歌曲正規化。驗收：相鄰濾波重疊與低架增強一起估算；對照 Apple 實際離線 PCM；模型／取樣率／殘響混合處理一致；互動說明可切換路徑、方案及新舊曲線；同步日誌與原生包。

已知風險：頻率響應上界不是任意波形的瞬態／true-peak 上界，3 dB 是工程預留值，不是保證。更新後同一個 App／車機音量可能明顯比舊版大，初次比較先降低播放音量。沒有宣稱完整增益平滑或全取樣率矩陣完成。

## 為什麼先做方案 A

| 方案 | 範圍／收益 | 目前狀態 |
|---|---|---|
| A 合成頻率響應餘裕 | 直接修正已確認的過度衰減，不持續改變音樂動態 | 本輪已接入並以 PCM 驗證 |
| B EQ 前後響度補償 | 接近原本聽感音量；需處理靜音、分析視窗、補償上限與抽動 | 尚未實作 |
| C 輸出峰值限制器 | 處理短暫峰值；需驗證延遲、攻擊／釋放、true-peak 與動態 | 尚未實作 |
| D 歌曲正規化 | 平衡不同歌曲；需要曲目分析與資料保存 | 尚未實作 |

B／C 可以互補，但本輪依要求不一起加入。A 不是完整的音量維持方案，而是先移除已確認的根因。不能改成只取最高滑桿，因相鄰頻段與低音低架仍會重疊。

## 正式音訊路徑

`音檔解碼 → Apple EQ（globalGain 前級補償＋10 段濾波）→ 90 Hz 低架 → 殘響 → App 音量 → 系統輸出`

正式濾波仍由 Apple 音訊單元處理，沒有改為 Rust。`EQHeadroom.swift` 只估算響應與補償值，不在即時 render callback 執行音檔分析。模型使用 RBJ／W3C 的 peaking biquad（一倍頻程 BW）及低架 S=1，逐頻率把串接濾波器的 dB 響應相加。

1. 清理輸入：EQ ±12 dB，低架 0～+9 dB，處理非有限值。
2. 依音檔取樣率排除 Apple 端同樣被旁通的高頻段（頻率 ≥ 0.45 × 取樣率）。
3. 掃描 769 個對數點，以及各頻段中心、90 Hz、DC；上限為 0.499 × 取樣率。
4. 取整條合成曲線的最高正增益；不把負增益任意抵銷另一個頻率的正增益。
5. 加 3 dB 基本餘裕。選空間效果且混合量 > 0 才加 6 dB 殘響預留；殘響的這 6 dB 仍是固定保守值，並非模型量測。
6. 將負值套用到 Apple EQ 的 globalGain。旁通仍保留同一份補償供濾波 A/B；不是未衰減原始電平。最大衰減 96 dB。

公式：`補償 dB = −min(96, 3 + max(0, 合成響應最高 dB) + 有效殘響預留)`。

## 可重現範例（44.1 kHz）

| 設定 | 舊版整體增益 | 新版整體增益 |
|---|---:|---:|
| 原音 | −3.00 dB | −3.00 dB |
| 32／1k／16k 各 +3 dB | −12.00 dB | −6.02 dB |
| 十段各 +3 dB | −33.00 dB | −7.76 dB |
| 低頻預設 | −16.50 dB | −7.78 dB |
| 低頻預設＋低音 +6 dB | −22.50 dB | −13.66 dB |
| 演唱會／18% 殘響 | −12.00 dB | −10.19 dB |
| 演唱會／0% 殘響 | −12.00 dB | −4.19 dB |

這是前級增益差，不能把它當成感知響度變化量。範例由正式 Swift 估算器輸出成 `planning/eq-technical.json`，瀏覽器不另寫一套近似算法。

## 驗收結果

- 原生離線引擎共 125 個探測點：16／44.1／48 kHz；十段 +3、十段 +12 並低架 +9、±12 交錯並低架 +6、低頻預設並低架 +3、全頻削減。
- 實際 Apple 濾波響應與估算最大差異 0.029 dB，最大低估 0.014 dB；所有測試穩態音調經新補償後仍留有餘裕。這不等於任意樂曲、全頻連續掃描或重建 true-peak 驗收。
- 原有 1 kHz +6 dB、低架 32 Hz、4 kHz 不受低架增強、殘響尾音與旁通測試通過。新低架量測約 +5.90 dB；殘響尾音 RMS 0.00060851、旁通 0。
- 模型測試：合成餘裕、非有限輸入、低取樣率、0% 殘響混合、舊設定與既有模式／歌曲綁定／播放狀態皆通過。
- 瀏覽器已驗證：技術區塊深連結、音訊步驟切換、方案 A／B 內容切換、範例顯示新舊衰減與 SVG 曲線。最終 macOS arm64 與 generic iOS Simulator arm64 建置通過；Xcode 真機產物版本 0.5.0／6 且顯示正在實體 iPhone 執行。手機完整音訊操作、實車與背景／中斷驗收仍待完成。

證據產物：`.build/checks/native-eq-result.txt`、`response-comparison.csv`、`results.log`（測試暫存，忽略版控）。測試來源：`Tests/NativeEQChecks.swift`、`Tests/AudioChecks.swift`。主要實作：`EQHeadroom.swift`、`AudioPlayback.swift`、`PlayerModel.swift`、`planning/eq-technical-panel.html`。

## 重建與維護

```sh
python3 scripts/generate_eq_technical.py
python3 scripts/generate_xcode_project.py
python3 planning/build_inspector.py
python3 planning/validate_plan.py
node --check /private/tmp/orca-inspector-check.js
python3 scripts/check_audio.py
```

估算器變動時必須重新輸出技術範例，且原生 PCM 誤差需重新量測。不能只改網頁示意值。

## 官方依據與區分

- [W3C Audio EQ Cookbook](https://www.w3.org/TR/audio-eq-cookbook/)：串接濾波器的 biquad 響應計算依據；不宣稱 Apple 公開了相同內部係數。
- [Roon Headroom Management](https://help.roonlabs.com/portal/en/kb/articles/dsp-engine-headroom-management)：DSP 可能造成削波，餘裕與實際削波指示需區分。
- [FabFilter Output Options](https://www.fabfilter.com/help/pro-q/using/output)：Auto Gain 是依 EQ 設定估算，與動態量測響度不同；本輪也尚未加入此功能。
