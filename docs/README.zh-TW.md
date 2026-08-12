# Soniqo 台灣繁體中文說明

Soniqo 是一款 macOS 選單列 App，會讓系統音訊輸出跟著目前播放視窗所在的螢幕移動。

把 YouTube、音樂或影片視窗移到另一個螢幕時，Soniqo 可以將 macOS 預設輸出切換到該螢幕所對應的音訊裝置。選單會列出目前所有可用螢幕，包括 MacBook 內建螢幕，並顯示各螢幕的輸出映射、連線狀態與 Core Audio 能讀取的目前音量。

文件：[English](../README.md) / **繁體中文** / [简体中文](README.zh-CN.md)

## 功能

- 顯示 macOS 目前可用的全部螢幕，包括內建螢幕。
- 為每一個螢幕設定對應的 Core Audio 輸出裝置。
- 播放中的視窗移到其他螢幕時，自動切換系統音訊輸出。
- 顯示目前系統輸出及每個已設定輸出的即時音量。
- 裝置支援軟體音量時，提供可拖曳的音量滑桿。
- 為每個已設定的螢幕提供一鍵手動切換。
- Auto 模式只會鎖定手動切換，音量仍可調整。
- 明確區分已中斷、不可用、未設定、狀態未知及由裝置控制音量等狀態。
- 選單會依內容增加高度，只有超過目前螢幕可用空間時才捲動。

## 系統需求

- macOS 14.2 或以上版本。
- 至少一個 Core Audio 音訊輸出裝置。
- Soniqo 必須先知道螢幕與輸出的對應關係，才能把音訊切換到該螢幕。

## 使用方式

1. 從選單列開啟 Soniqo。
2. 點擊螢幕卡片上的齒輪，選擇要對應的音訊輸出。
3. 開啟 **Auto**，讓目前有聲音的播放視窗自動決定系統輸出。
4. 關閉 **Auto** 後，可按螢幕卡片上的播放按鈕立即手動切換。
5. 拖曳螢幕卡片上的音量滑桿即可調整該輸出；Auto 開啟時也能調整音量。

**SYSTEM** 標籤代表 macOS 目前正在使用的輸出；**ACTIVE** 標籤代表 Soniqo 正在追蹤的播放視窗所在螢幕。

## 音訊與路由限制

Soniqo 切換的是 macOS 全系統的預設輸出，無法同時把不同 App 分別送到不同音訊裝置。

並非所有音訊裝置都提供可寫入的軟體音量。HDMI、DisplayPort、電視、接收器與部分顯示器通常必須直接在硬體上調整音量。Soniqo 會把這類裝置標示為 **Device Controlled**，而不會顯示無法使用的假滑桿。Core Audio 顯示的百分比也不一定等同於顯示器或接收器畫面上的實體音量。

macOS 沒有提供適用於所有硬體的螢幕與音訊裝置對應 API。Soniqo 會使用已儲存的映射，以及保守的名稱和內建裝置比對；如果有多個同名裝置或關係不明確，會保持未設定，避免宣稱錯誤的對應。請使用齒輪按鈕補充或修正設定。

播放視窗偵測依賴 macOS 回報的音訊行程與可見視窗。瀏覽器 helper process、隱藏視窗、受保護內容，或使用特殊行程架構的 App，偶爾可能無法立即正確配對。

## 建置

用 Xcode 開啟 `Soniqo.xcodeproj`，執行 `Soniqo` Scheme。

本機未簽署建置：

```sh
xcodebuild \
  -project Soniqo.xcodeproj \
  -scheme Soniqo \
  -configuration Debug \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

專案沒有外部 package 相依性。Soniqo 只在選單列運行，不會顯示 Dock 圖示或一般主視窗。

## 打包

這個 repository 內含 GitHub Actions workflow。分支、Pull Request 與手動執行會產生 ad-hoc 簽署的開發用成品；官方 repository 的版本 tag 則會產生 Developer ID 簽署並經 Apple 公證的正式版本。

如果要從 fork 或開發分支建置，可以在 GitHub Actions 手動執行 `Build and Release` workflow。若要在自己的 fork 中把打包檔附到 GitHub Release，推送版本 tag：

```sh
git tag v1.0.0
git push origin v1.0.0
```

workflow 會建置 universal macOS App（`arm64` 與 `x86_64`），從 tag 設定 App 版本（`v1.0.0` 會變成 `1.0.0`），使用 GitHub Actions run number 作為 build number，並打包：

- `Soniqo-1.0.0.dmg`
- `Soniqo-1.0.0-macOS-universal.zip`
- `SHA256SUMS`

官方版本 tag 會使用 Developer ID Application 憑證簽署、提交 Apple 公證、staple 公證票證，並在發佈前通過 Gatekeeper 檢查。正式發佈 workflow 需要以下 repository secrets：

```text
MACOS_CERTIFICATE
MACOS_CERTIFICATE_PASSWORD
APPLE_ID
APPLE_APP_SPECIFIC_PASSWORD
APPLE_TEAM_ID
```

沒有正式發佈憑證時產生的開發用成品只會以 ad-hoc 簽署，不適合提供給一般使用者。

## 開發方向

- 改善瀏覽器與媒體 App 的播放視窗偵測。
- 為多個同時播放的視窗加入優先順序規則。
- 使用 Core Audio property listener 即時回應裝置、預設輸出、音量與靜音變更。
- 研究真正的 per-window 音訊路由，讓多螢幕可以同時使用不同輸出。
