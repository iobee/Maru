# Maru 风格好搭子组合控制实施计划

日期：2026-07-12  
目标：把首页两个同级系统选项收敛成一个推荐组合控制，并默认隐藏独立选择。

## 文件范围

- `Sources/Maru/Services/DockSettings.swift`：Dock 自动隐藏系统读写
- `Sources/Maru/Services/StageManagerSettings.swift`：Stage Manager 系统读写及错误保留
- `Sources/Maru/Models/HomeDashboardState.swift`：组合状态、文案和最小写入计划
- `Sources/Maru/Views/HomeDashboardView.swift`：组合卡与默认折叠的独立设置
- `Sources/Maru/MaruApp.swift`：注入 Dock 状态对象
- `Tests/MaruTests/HomeDashboardStateTests.swift`：组合状态和写入计划
- `Tests/MaruTests/StageManagerSettingsTests.swift`：写入失败状态
- `Tests/MaruTests/DockSettingsTests.swift`：Dock 系统控制与失败状态

## 实施步骤

- [x] 建立 `DockSettings` 系统控制层并注入首页
- [x] 在首页状态中加入 Stage Manager 与 Dock 组合状态
- [x] 定义关闭、部分开启、全部开启三种展示状态
- [x] 定义只写入缺失设置的 `CompanionChangePlan`
- [x] 用单一 `Maru 风格好搭子` 卡替换两个同级卡片
- [x] 将窗口自动管理 Hero 恢复到组合卡之前
- [x] 用默认收起的 `DisclosureGroup` 承载独立开关
- [x] 让两项写入错误在折叠区域外保持可见
- [x] 补充组合状态、开启计划、关闭计划和写入错误测试
- [x] 运行全量测试和 release build
- [x] 启动本地 `.app`，检查默认折叠、视觉层级和展开布局
- [x] 按验收标准完成最终审计

## 验证命令

```bash
swift test --filter HomeDashboardStateTests
swift test --filter StageManagerSettingsTests
swift test --filter DockSettingsTests
swift test --quiet
swift build -c release
git diff --check
```

界面验证使用本地 app bundle：

```bash
MARU_SKIP_SWIFT_BUILD=1 ./Scripts/package-local.sh
open -n Release/Local/Maru.app
```
