# Maru 检查更新功能 Spec

日期：2026-04-26  
状态：已完成设计确认，待实现  
范围：接入 Sparkle 2 更新检查、状态栏菜单顺序调整、About 页轻量更新探测、发布流程约定

## 1. 目标

为 Maru 增加符合 macOS 习惯的更新能力，同时保持产品本身轻量、克制、像原生桌面工具。

本次目标：

- 使用成熟的 macOS 更新框架，不自研下载、校验和安装流程
- 通过 GitHub Releases 发布安装包
- 通过 GitHub Pages 托管 Sparkle appcast
- 保留状态栏菜单里的手动检查更新入口
- About 页不改现有产品名片设计，只在进入页面时做一次轻量更新探测
- 不增加自动检查更新 Toggle，不把 About 页改成设置页

## 2. 已确认决策

用户已确认以下方向：

- 采用方案 1：`Sparkle 2 + GitHub Releases + GitHub Pages appcast`
- 仓库地址：`https://github.com/iobee/Maru.git`
- appcast 地址：`https://iobee.github.io/Maru/appcast.xml`
- About 页不新增“检查更新”按钮
- About 页不新增“自动检查更新”Toggle
- 进入 About 页时默认检查是否有更新，并显示系统圆形加载动画
- 状态栏图标菜单保留“检查更新…”手动入口
- 状态栏图标菜单不新增“查看日志”
- 状态栏图标菜单里 `配置` 改为 `应用配置`

## 3. 更新架构

### 3.1 框架选择

使用 Sparkle 2 作为更新框架。

Maru 不直接实现以下能力：

- 下载更新包
- 校验更新包签名
- 展示完整更新安装流程
- 替换正在运行的应用
- 处理跳过版本、稍后安装、重启安装等复杂状态

这些全部交给 Sparkle 的标准实现。

### 3.2 核心组件

新增一个薄封装服务：

`UpdateService`

职责：

- 持有 `SPUStandardUpdaterController`
- 暴露手动检查入口：调用 Sparkle 的 `checkForUpdates(_:)`
- 暴露 About 页探测入口：调用 `SPUUpdater.checkForUpdateInformation()`
- 通过 `SPUUpdaterDelegate` 接收探测结果
- 向 SwiftUI 暴露轻量状态：`idle`、`checking`、`updateAvailable`、`failed`
- 将错误写入 `AppLogger`，不在 About 页展示诊断细节

状态模型建议：

```swift
enum UpdateProbeState: Equatable {
    case idle
    case checking
    case updateAvailable
    case failed
}
```

`UpdateService` 只负责桥接 Sparkle 与 Maru UI，不保存独立更新偏好。Sparkle 自己会通过 host bundle 的 user defaults 管理自动检查相关设置。

### 3.3 Sparkle API 使用边界

手动检查：

- 使用 `SPUStandardUpdaterController.checkForUpdates(_:)`
- 由用户从菜单触发
- 可以显示 Sparkle 原生进度、无更新提示或更新窗口

About 页轻量探测：

- 使用 `SPUUpdater.checkForUpdateInformation()`
- 只探测是否存在有效更新，不直接弹安装 UI
- 通过 delegate 更新 About 页的小型状态
- 如果已有 Sparkle session 正在进行，则不重复触发
- 每个 app session 内进入 About 页最多自动探测一次，避免反复切页造成网络请求和状态闪烁

避免在 About 页进入时调用 `checkForUpdatesInBackground()`。Sparkle 文档说明这个 API 通常由 Sparkle 的自动计划调度调用，后续时间点手动调用可能干扰调度周期。

## 4. 配置设计

### 4.1 `Info.plist`

需要新增 Sparkle 配置：

- `SUFeedURL`
  - 值：`https://iobee.github.io/Maru/appcast.xml`
- `SUPublicEDKey`
  - 值：通过 Sparkle `generate_keys` 生成的 EdDSA 公钥
- `SUEnableAutomaticChecks`
  - 值：`true`

不配置 `SUAutomaticallyUpdate` 为 `true`。第一版不做静默自动安装，只允许 Sparkle 在发现更新时提示用户。

### 4.2 版本号规则

继续使用：

- `CFBundleShortVersionString`：面向用户展示的版本号，例如 `1.0.0`
- `CFBundleVersion`：递增 build 号，供 Sparkle 判断更新顺序

发布新版本时必须递增 `CFBundleVersion`。只改展示版本号但不递增 build 号，会导致 Sparkle 无法正确识别更新。

## 5. 状态栏菜单设计

本次调整的是右上角 Maru 状态栏图标点开的菜单。

最终顺序：

```text
窗口自动管理

居中窗口
呼吸窗口
移到下一显示器

应用配置
应用规则
检查更新…

退出
```

规则：

- `窗口自动管理` 位于最上方，作为 Maru 主开关
- 手动窗口操作位于中间，保持高频快捷操作可达
- `应用配置`、`应用规则`、`检查更新…` 位于底部管理入口组
- `检查更新…` 是该管理入口组最后一项
- 不新增 `查看日志`
- 原 `配置` 文案改为 `应用配置`

macOS 顶部应用菜单也可以增加标准的 `检查更新…` 入口，调用同一套 `UpdateService` 手动检查方法。这个入口符合 macOS 应用习惯，但不影响状态栏菜单的确认顺序。

## 6. About 页设计

About 页保持当前产品名片设计，不做结构重排。

允许的最小变化：

- 进入 About 页时触发一次轻量更新探测
- 探测中在现有版本信息附近显示一个小型系统圆形 `ProgressView`
- 加载动画尺寸必须小，不能抢占 Maru 名片视觉中心
- 加载动画结束后默认消失

不做的事情：

- 不新增“检查更新…”按钮
- 不新增“自动检查更新”Toggle
- 不新增大型更新状态卡
- 不新增发布通道、当前版本、最新版本等复杂信息区
- 不把网络错误展示成 About 页错误面板

更新结果表达：

- 无更新：加载动画消失，不长期展示“已是最新版本”
- 网络失败：加载动画消失，错误写入 `AppLogger`
- 有更新：允许在版本行附近显示一条极低优先级状态文案，例如 `发现新版本`；用户如果要主动打开更新流程，可使用状态栏菜单底部的 `检查更新…`

如果实现时发现 `发现新版本` 文案会破坏现有视觉平衡，第一版可以只记录状态并依赖手动菜单入口，不在 About 页持续展示结果。

## 7. 发布流程

发布源分工：

- GitHub Releases：存放 `.dmg` 或 `.zip` 更新包
- GitHub Pages：托管 `appcast.xml` 和可选 release notes

推荐发布步骤：

1. 更新 `CFBundleShortVersionString`
2. 递增 `CFBundleVersion`
3. 执行 release build
4. 代码签名
5. notarize
6. 打包 `.dmg` 或 `.zip`
7. 使用 Sparkle 工具生成 EdDSA 签名和 appcast
8. 上传安装包到 GitHub Release
9. 更新 GitHub Pages 中的 `appcast.xml`
10. 用旧版本 Maru 验证能发现新版本

第一版实现可以先接入 Sparkle 和菜单入口。正式公开发布前必须补齐签名、notarize、appcast 生成和旧版本更新验证。

## 8. 错误处理

更新错误不应影响窗口管理主功能。

处理规则：

- Sparkle 配置错误：启动时由 Sparkle 标准行为提示开发者问题；同时写入 `AppLogger`
- appcast 不存在：手动检查时交给 Sparkle 原生提示；About 页探测只写日志
- 网络失败：不崩溃，不阻塞 About 页
- 签名失败：交给 Sparkle 拒绝更新，日志记录错误
- 正在检查或下载：状态栏菜单的 `检查更新…` 应根据 `canCheckForUpdates` 禁用或保持 Sparkle 标准校验行为

## 9. 测试验收

实现完成后应满足：

- `origin` 指向 `https://github.com/iobee/Maru.git`
- About 页 GitHub 链接指向 `https://github.com/iobee/Maru`
- 状态栏菜单顺序符合本 spec
- 状态栏菜单中 `配置` 已改为 `应用配置`
- 状态栏菜单不新增 `查看日志`
- 点击 `检查更新…` 会调起 Sparkle 手动检查流程
- 进入 About 页会触发轻量探测，并显示小型圆形加载动画
- About 页探测不会弹出 Sparkle 更新安装窗口
- appcast 不存在或网络失败时应用不崩溃
- `CFBundleVersion` 递增时，旧版本可以通过 appcast 识别新版本
- 无更新、有更新、网络失败三种路径都有日志或可观察状态

## 10. 实现边界

本 spec 不包含：

- 自研更新下载器
- 自研更新安装 UI
- 自动静默安装
- beta / stable 多通道发布
- 更新偏好页
- About 页重设计
- GitHub Actions 全自动发布流水线

后续可以单独设计 release automation，把打包、签名、notarize、生成 appcast、上传 release 串成脚本或 CI。

## 11. 参考资料

- Sparkle 文档：`https://sparkle-project.org/documentation/`
- Sparkle programmatic setup：`https://sparkle-project.org/documentation/programmatic-setup/`
- Sparkle publishing updates：`https://sparkle-project.org/documentation/publishing/`
- Sparkle `SPUUpdater` API：`https://sparkle-project.org/documentation/api-reference/Classes/SPUUpdater.html`
- Sparkle `SPUStandardUpdaterController` API：`https://sparkle-project.org/documentation/api-reference/Classes/SPUStandardUpdaterController.html`
