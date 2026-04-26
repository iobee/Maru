# Maru

**Center it beautifully.**

一键居中，让日常更优雅。

Maru 是一款 macOS 开源工具，可自动将窗口优雅地移动到屏幕中央，让桌面始终简洁、平衡、顺手。

## 应用特点

- **精心打磨**：我自己每天都在用的产品，持续优化细节，把好的体验交到你手里
- **呼吸窗口**：留白让窗口有了呼吸感，使用电脑时更惬意、更优雅

## 安装

### 安装包（推荐）

前往 [Releases](https://github.com/iobee/Maru/releases) 页面，下载最新版本的 DMG 文件，打开后将 **Maru.app** 拖入「应用程序」文件夹即可。

### 本地编译

```bash
swift build -c release && cp -r .build/release/Maru.app /Applications/
```

需要 macOS 13.0+、Swift 5.8+。

## 权限

首次启动时，Maru 会请求**辅助功能**权限，用于读取和移动窗口位置。按系统提示前往「系统设置 > 隐私与安全性」开启即可。

所有配置和日志仅保存在本机 `~/Library/Application Support/Maru/`，不进行网络通信。

## 参与贡献

这个是利用个人的闲暇时间和 AI 一起创作出来一个作品，难免会有很多缺点。大家在使用过程中遇到什么痛点或者 bug，欢迎大家一起提交代码共建或者提 issue 给我。
