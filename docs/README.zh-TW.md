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
