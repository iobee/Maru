# 窗口管理器 (HiWindowGuy)

这是一个简单的macOS窗口管理应用，用于自动调整窗口大小和位置。该应用根据不同的应用类型执行不同的窗口管理操作：

- 对于消息类应用（如WeChat、Messages、Telegram等），窗口将居中显示
- 对于其他应用，窗口将几乎最大化（保留边距）
- 某些特定应用会被忽略（如HiTranslator、Raycast等）

## 功能特点

- 自动检测活动窗口并应用相应的窗口布局
- 使用延迟处理（debounce）避免频繁调整
- 支持在后台运行（状态栏应用）
- 可通过状态栏图标控制启用/禁用
- 支持 Sparkle 应用更新（启动自动检查 + 手动检查）

## 安装与使用

### 构建方法

使用Swift Package Manager构建应用：

```bash
swift build
```

或者在Xcode中打开Package.swift文件进行构建。

### 使用方法

1. 启动应用后，它会显示在状态栏中
2. 点击状态栏图标可以打开控制菜单
3. 窗口管理功能默认启用，可以在应用界面中通过开关控制
4. 可从应用菜单或状态栏菜单执行“检查更新…”

## 应用更新配置

项目已接入 [Sparkle](https://sparkle-project.org) 作为自更新框架，并默认使用 GitHub Releases + GitHub Pages appcast。

### 运行时行为

- 启动后会尝试自动检查更新
- 用户可随时从菜单手动执行“检查更新…”
- 如果发现新版本，将使用 Sparkle 标准更新界面提示安装
- 如果未配置 Sparkle 公钥，应用会记录日志并禁止更新检查

### 需要补全的发布配置

在正式发布前，需要确保打包进 `.app` 的 `Info.plist` 含有以下键：

```xml
<key>SUFeedURL</key>
<string>https://iobee.github.io/hiWindowGuy/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_ED25519_KEY</string>
```

当前仓库中的 `Sources/HiWindowGuy/Info.plist` 已包含占位值，但由于本项目是 Swift Package，最终发布产物仍需要确认实际 `.app` 内的 `Info.plist` 也带有这些值。

### 发布流程建议

1. 使用 Sparkle 的 `generate_keys` 生成 Ed25519 密钥对，并把公钥写入应用 `Info.plist`
2. 对每个发布版本构建并签名 `.app`
3. 使用 Sparkle 的 `generate_appcast` 生成 `appcast.xml`
4. 将发布归档上传到 GitHub Releases
5. 将 `appcast.xml` 发布到 GitHub Pages 或其他 HTTPS 静态托管地址

## 系统要求

- macOS 11.0 或更高版本

## 隐私说明

该应用需要以下权限：

- 屏幕录制权限（用于获取窗口信息）
- AppleScript自动化权限（用于调整窗口大小和位置）

## 从Hammerspoon迁移

这个应用是从Hammerspoon Lua脚本转换而来，提供相同的窗口管理功能，但作为独立的原生Swift应用运行。 
