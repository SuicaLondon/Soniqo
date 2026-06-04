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
