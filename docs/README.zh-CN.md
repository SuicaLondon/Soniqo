# Soniqo 中文说明

Soniqo 是一个 macOS 菜单栏应用，用来做基于屏幕位置的音频输出切换。

最终目标：窗口在哪个 monitor 就哪个 monitor 发声。

比如 YouTube 窗口在 Dell 显示器上，就走 Dell 显示器音频；把同一个窗口拖回 MacBook 屏幕，就切回 MacBook 扬声器。

这个体验面向多屏用户，目标是让声音更贴近窗口所在的位置，形成类似“屏幕本地化”的空间感。

## 当前支持

- 菜单栏应用。
- 自动切换输出。
- 播放窗口追踪。

## 构建

用 Xcode 打开 `Soniqo.xcodeproj`，运行 `Soniqo` scheme。

无签名本地构建：

```sh
xcodebuild -project Soniqo.xcodeproj -scheme Soniqo -configuration Debug -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

## 打包

这个 repository 包含 GitHub Actions workflow，方便协作者或 fork 维护者自行构建可下载的 App bundle。

如果要从 fork 或开发分支构建，可以在 GitHub Actions 手动运行 `Build and Release` workflow。若要在自己的 fork 中把打包文件附到 GitHub Release，推送版本 tag：

```sh
git tag v1.0.0
git push origin v1.0.0
```

workflow 会构建 universal macOS App（`arm64` 和 `x86_64`），从 tag 设置 App 版本（`v1.0.0` 会变成 `1.0.0`），使用 GitHub Actions run number 作为 build number，进行 ad-hoc 签名，并打包：

- `Soniqo-1.0.0.dmg`
- `Soniqo-1.0.0-macOS-universal.zip`

这些自行构建的 package 没有经过 Apple notarization。测试本地或 fork build 时，macOS 可能会要求第一次打开时右键选择“打开”，或在下载后移除 quarantine：

```sh
xattr -dr com.apple.quarantine /Applications/Soniqo.app
```
