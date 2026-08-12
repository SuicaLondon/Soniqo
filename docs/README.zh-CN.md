# Soniqo 简体中文说明

Soniqo 是一个 macOS 菜单栏应用，可以让系统音频输出跟随当前播放窗口所在的屏幕。

把 YouTube、音乐或视频窗口移到另一台显示器时，Soniqo 可以将 macOS 默认输出切换到该显示器所映射的音频设备。菜单会列出当前所有可用屏幕，包括 MacBook 内置屏幕，并显示各屏幕的输出映射、连接状态以及 Core Audio 能读取的当前音量。

文档：[English](../README.md) / [繁體中文](README.zh-TW.md) / **简体中文**

## 功能

- 显示 macOS 当前可用的全部屏幕，包括内置屏幕。
- 为每个显示器设置对应的 Core Audio 输出设备。
- 播放窗口移动到其他屏幕时，自动切换系统音频输出。
- 显示当前系统输出及每个已配置输出的实时音量。
- 设备支持软件音量时，提供可拖动的音量滑块。
- 为每个已配置的显示器提供一键手动切换。
- Auto 模式只会锁定手动切换，音量仍可调整。
- 明确区分已断开、不可用、未配置、状态未知以及由设备控制音量等状态。
- 菜单会根据内容增加高度，只有超过当前屏幕可用空间时才滚动。

## 系统要求

- macOS 14.2 或更高版本。
- 至少一个 Core Audio 音频输出设备。
- Soniqo 必须先知道显示器与输出的对应关系，才能把音频切换到该显示器。

## 使用方法

1. 从菜单栏打开 Soniqo。
2. 点击显示器卡片上的齿轮，选择要映射的音频输出。
3. 开启 **Auto**，让当前有声音的播放窗口自动决定系统输出。
4. 关闭 **Auto** 后，可以点击显示器卡片上的播放按钮立即手动切换。
5. 拖动显示器卡片上的音量滑块即可调整该输出；Auto 开启时仍可调整音量。

**SYSTEM** 标签表示 macOS 当前正在使用的输出；**ACTIVE** 标签表示 Soniqo 正在跟踪的播放窗口所在屏幕。

## 音频与路由限制

Soniqo 切换的是 macOS 全系统默认输出，不能同时把不同应用分别发送到不同音频设备。

并非所有音频设备都提供可写的软件音量。HDMI、DisplayPort、电视、接收器及部分显示器通常必须直接在硬件上调整音量。Soniqo 会把这类设备标记为 **Device Controlled**，而不会显示无法使用的假滑块。Core Audio 显示的百分比也不一定等同于显示器或接收器画面上的物理音量。

macOS 没有提供适用于所有硬件的显示器与音频设备关联 API。Soniqo 会使用已保存的映射，以及保守的名称和内置设备匹配；如果存在多个同名设备或关系不明确，就会保持未配置，避免声称错误的关联。请使用齿轮按钮补充或修正设置。

播放窗口检测依赖 macOS 报告的音频进程与可见窗口。浏览器 helper process、隐藏窗口、受保护内容，或采用特殊进程架构的应用，偶尔可能无法立即正确匹配。

## 构建

用 Xcode 打开 `Soniqo.xcodeproj`，运行 `Soniqo` Scheme。

本地无签名构建：

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

项目没有外部 package 依赖。Soniqo 只在菜单栏运行，不会显示 Dock 图标或常规主窗口。

## 打包

这个 repository 包含 GitHub Actions workflow。分支、Pull Request 与手动运行会生成 ad-hoc 签名的开发产物；官方 repository 的版本 tag 则会生成 Developer ID 签名并经过 Apple 公证的正式版本。

如果要从 fork 或开发分支构建，可以在 GitHub Actions 手动运行 `Build and Release` workflow。若要在自己的 fork 中把打包文件附到 GitHub Release，推送版本 tag：

```sh
git tag v1.0.0
git push origin v1.0.0
```

workflow 会构建 universal macOS App（`arm64` 和 `x86_64`），从 tag 设置 App 版本（`v1.0.0` 会变成 `1.0.0`），使用 GitHub Actions run number 作为 build number，并打包：

- `Soniqo-1.0.0.dmg`
- `Soniqo-1.0.0-macOS-universal.zip`
- `SHA256SUMS`

官方版本 tag 会使用 Developer ID Application 证书签名、提交 Apple 公证、staple 公证票证，并在发布前通过 Gatekeeper 检查。正式发布 workflow 需要以下 repository secrets：

```text
MACOS_CERTIFICATE
MACOS_CERTIFICATE_PASSWORD
APPLE_ID
APPLE_APP_SPECIFIC_PASSWORD
APPLE_TEAM_ID
```

没有正式发布凭证时生成的开发产物只会以 ad-hoc 签名，不适合提供给普通用户。

## 开发方向

- 改进浏览器与媒体应用的播放窗口检测。
- 为多个同时播放的窗口添加优先级规则。
- 使用 Core Audio property listener 实时响应设备、默认输出、音量及静音变化。
- 研究真正的 per-window 音频路由，让多屏幕可以同时使用不同输出。
