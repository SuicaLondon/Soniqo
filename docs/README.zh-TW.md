# Soniqo 台灣繁體中文說明

Soniqo 是一款 macOS 選單列 App，會依照播放視窗所在的螢幕，自動切換系統音訊輸出。

最終目標：視窗在哪個螢幕，就從哪個螢幕發聲。

例如 YouTube 視窗在 Dell 螢幕上，就切到 Dell 螢幕的喇叭；把同一個視窗拖回 MacBook 螢幕，就切回 MacBook 內建喇叭。

這個體驗是為多螢幕使用者設計的，目標是讓聲音跟著視窗所在的位置走，帶來更接近空間音訊的使用感。

## 目前支援

- 選單列 App。
- 自動切換輸出。
- 播放視窗追蹤。

## 建置

用 Xcode 開啟 `Soniqo.xcodeproj`，執行 `Soniqo` Scheme。

本機未簽署建置：

```sh
xcodebuild -project Soniqo.xcodeproj -scheme Soniqo -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

## 打包

這個 repository 內含 GitHub Actions workflow，方便協作者或 fork 維護者自行建立可下載的 App bundle。

如果要從 fork 或開發分支建置，可以在 GitHub Actions 手動執行 `Build and Release` workflow。若要在自己的 fork 中把打包檔附到 GitHub Release，推送版本 tag：

```sh
git tag v1.0.0
git push origin v1.0.0
```

workflow 會建置 universal macOS App（`arm64` 與 `x86_64`），從 tag 設定 App 版本（`v1.0.0` 會變成 `1.0.0`），使用 GitHub Actions run number 作為 build number，進行 ad-hoc 簽署，並打包：

- `Soniqo-1.0.0.dmg`
- `Soniqo-1.0.0-macOS-universal.zip`

這些自行建置的 package 沒有經過 Apple notarization。測試本機或 fork build 時，macOS 可能會要求第一次開啟時右鍵選擇「打開」，或在下載後移除 quarantine：

```sh
xattr -dr com.apple.quarantine /Applications/Soniqo.app
```
