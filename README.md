# Maru

Center it beautifully.

一键居中，让日常更优雅。

Maru 是一款 macOS 开源工具，可自动将窗口优雅地移动到屏幕中央，让桌面始终简洁、平衡、顺手。

## 功能特点

- 自动检测活动窗口并应用对应布局规则
- 将消息类应用窗口居中显示
- 将常规应用几乎最大化，并保留可调留白
- 支持忽略指定应用
- 通过菜单栏常驻运行，可快速启用或暂停窗口管理
- 内置应用规则、手动控制、日志和关于页面

## 构建与运行

```bash
swift build
swift run Maru
```

构建 release 版本：

```bash
swift build -c release
```

## 系统要求

- macOS 13.0 或更高版本
- Swift 5.8 或更高版本

## 权限说明

Maru 需要以下系统权限来读取和调整窗口：

- 辅助功能权限
- 屏幕录制权限
- 自动化权限

所有配置和日志都保存在本机 `~/Library/Application Support/Maru/`，应用不进行网络通信。

## 来源

Maru 从早期 Hammerspoon Lua 脚本迁移为独立的原生 SwiftUI 应用。
