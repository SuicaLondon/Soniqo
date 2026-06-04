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
