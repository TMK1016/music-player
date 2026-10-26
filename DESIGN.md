# Music Player 設計來源

2026-10-26｜播放頁改版。使用者兩張標註圖為本次頁面配置來源：docs/design/references/playback-annotated.png、inline-equalizer.png。技術為原生SwiftUI，不引入Web元件庫。

## 保留的視覺系統

背景#080F1B、面板#101D2E、抬升面板#15263B、主色#398CFF、互動青色#6BD8FF、主要文字#F1F6FF、次要文字#99AEC8。直接使用OrcaTheme語意色。系統字體，主要歌名title2／semibold、內文subheadline、時間caption2／monospacedDigit。沿用既有50%歌曲卡背景；不將整列文字設為半透明。

## 播放頁層次

頂部僅頁名，不顯示技術播放狀態列。封面面：右上五個空心／實心星 → 專輯封面 → 歌名 → 歌手 → 右側加入清單／收藏／定時。取消原頂部音效模式標籤及『未評分』文字。

封面向右滑超過48pt且橫向位移大於縱向1.5倍，切至EQ面；手勢只在封面區，不覆蓋星等、進度、EQ滑桿或模式橫列。EQ使用現有7段控制及模式，滑桿事件直接送既有播放器。主播放器及PlayerModel不重建音訊、不重新選曲。

兩面共享固定底部進度、時間及播放控制。播放模式整合單一Menu：順序／單曲重複／清單循環／隨機，選一項會清掉衝突旗標。下方再接三頁導覽。封面／調音提供44pt明確按鈕入口；EQ面另有返回封面。不強迫只靠滑動。

## 評分、尺寸與動態

五星各44pt，整條220pt；點選或橫拖可設1～5星，未評分五框全空。幾何邊界限制合法值；相同值不重寫JSON。長按清除或VoiceOver清除動作可回未評分。VoiceOver提供整體數值及增減動作。評分不改收藏、不停播。

頁面內容可捲動，transport固定在父層安全區內；小螢幕／橫向／大字可捲內容而不遮播放控制。封面尺寸受可用高度限制，不強制把大字裁掉。切面動畫0.22秒，Reduce Motion時不加動畫。深色為既有產品設定；不宣稱新增淺色模式。

## 使用技能與適用範圍

本機UI UX Pro Max（Github/nextlevelbuilder/ui-ux-pro-max-skill/.claude/skills/ui-ux-pro-max/SKILL.md）已讀取，並查詢ux的swipe gesture alternative，採用手勢區域隔離與非拖曳替代入口。SwiftUI gesture state accessible首次無結果，依技能重試accessibility後取得原生語意、標籤與Reduce Motion指引。未將未命中結果當成規則；未安裝全域plugin或執行上游安裝程序。

對照pro-rules：已在程式安排44pt觸控、語意標籤、減少動畫、可捲內容與固定控制。375pt、橫向、大字及實際手勢仍需可執行的原生介面驗收，不能只因程式寫出便勾為已驗證。

## v0.9 新規格覆寫

以docs/zh-TW/三頁細節與單頁調音-v09.md為最新規格。首頁採IMG_9770.jpg；評分左上、模式右上，封面左滑；EQ無垂直捲動，窄短版壓縮曲線／模式標頭、寬短版左右重排。模式列不再展開完整列表，長按排序並持久化；居中命名面板底色opacity 0.5。睡眠與設定見最新文件。本輪技能搜尋modal keyboard focus命中焦點／遮擋規則；SwiftUI adaptive layout未命中，重試accessibility取得原生語意及減少動畫指引。測試清單仍需實際驗證，不因採用技能便勾選通過。
