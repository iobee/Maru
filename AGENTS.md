# Maru - AI Agent Development Guide

## Project Overview

Maru is a macOS open-source window utility written in Swift using SwiftUI. It automatically moves windows to the center of the screen so the desktop stays clean, balanced, and easy to use.

**Product Copy:**
- **Name**: Maru
- **Slogan**: Center it. Elevate your everyday.
- **Chinese Slogan**: 一键居中，让日常更优雅。
- **One-line Description**: Maru 是一款 macOS 开源工具，可自动将窗口优雅地移动到屏幕中央，让桌面始终简洁、平衡、顺手。

**Key Features:**
- Automatic window positioning and sizing based on app-specific rules
- Message apps (WeChat, Messages, Telegram) are centered
- General apps are "almost maximized" with configurable scaling
- Specific apps can be ignored
- Runs as a status bar application with enable/disable control
- Real-time logging and configuration interface

**System Requirements:**
- macOS 13.0 or higher (specified in Package.swift)
- Swift 5.8 or higher
- Accessibility permissions
- Screen recording permissions

## Technology Stack

- **Language**: Swift 5.8+
- **UI Framework**: SwiftUI
- **Build System**: Swift Package Manager (Package.swift)
- **Platform**: macOS 13.0+
- **Key APIs**: 
  - Accessibility API (AXUIElement)
  - NSWorkspace for application monitoring
  - Combine for reactive programming
  - AppKit for native macOS integration

## Project Structure

```
Sources/Maru/
├── MaruApp.swift          # Main app entry point, menu bar extra, window configuration
├── Maru.swift             # Shared module imports
├── Models/                       # Data models
│   ├── NavigationTab.swift       # Navigation state management
│   └── AppConfig.swift           # Configuration, app rules, persistence
├── Services/                     # Core business logic
│   ├── WindowManager.swift       # Window detection and manipulation engine
│   └── AppLogger.swift           # Comprehensive logging system
└── Views/                        # SwiftUI interface components
    ├── ContentView.swift         # Main app interface with sidebar navigation
    ├── RuleConfigView.swift      # Application rule management UI
    ├── LogViewer.swift           # Real-time log display with filtering
    ├── SearchBarView.swift       # Search component for rules
    └── SidebarView.swift         # Navigation sidebar
├── Utilities/                    # Utility files
│   └── demo.lua                  # Legacy Hammerspoon script reference
└── Assets.xcassets/              # App icons and resources
```

## UI Design Standard

All main-window UI work must follow the project-level design standard in `docs/PRODUCT-UI-DESIGN-STANDARD.md`.

### UI Source of Truth

For any work that changes files under `Sources/Maru/Views/`, agents must read `docs/PRODUCT-UI-DESIGN-STANDARD.md` first and align the design before implementing.

Priority order:
1. `docs/PRODUCT-UI-DESIGN-STANDARD.md` - product-level UI source of truth
2. `docs/superpowers/specs/2026-04-15-homepage-control-panel-design.md` - homepage-specific supplement
3. `docs/superpowers/specs/2026-04-17-sidebar-apple-cues-design.md` - sidebar-specific supplement

If a page-level spec conflicts with the product-level standard, the product-level standard wins.

### Required UI Constraints

- Keep the app visually aligned with a macOS utility console, not a web dashboard
- Use restrained sidebar glass and stable dark content surfaces
- Treat blue as the only primary accent color
- Do not introduce large glass content panels, colorful stats cards, or decorative gradients unless the design standard is updated first
- When adding a new page, decide whether it is a control page or a tool list page before designing the UI

## Core Architecture

### 1. Application Entry Point (`MaruApp.swift`)
- SwiftUI App protocol implementation
- Manages menu bar extra (MenuBarExtra)
- Handles window configuration (transparent title bar, Stage Manager compatibility)
- Manages accessibility permission requests
- Global keyboard shortcuts and menu commands

### 2. Window Management System (`Services/WindowManager.swift`)
- **Detection**: Monitors NSWorkspace notifications for app focus changes
- **Debouncing**: 0.3s delay to prevent rapid adjustments
- **Safety**: 1.5s cooldown between operations, operation flags to prevent conflicts
- **Coordinate Handling**: Converts between NSScreen and AXUIElement coordinate systems
- **Multi-screen Support**: Handles multiple displays with proper coordinate conversion
- **Window Rules**: Applies different behaviors based on AppConfig rules

### 3. Configuration System (`Models/AppConfig.swift`)
- **App Rules**: Per-application window handling rules (center, almostMaximize, ignore, custom)
- **Persistence**: JSON-based configuration stored in `~/Library/Application Support/Maru/`
- **Default Rules**: Pre-configured rules for common message apps and system apps
- **Dynamic Updates**: Real-time rule updates with immediate effect

### 4. Logging System (`Services/AppLogger.swift`)
- **Levels**: debug, info, warning, error
- **Storage**: File-based logging with 5MB size limit, 5 file rotation
- **Memory**: Keeps last 1000 entries in memory
- **UI Integration**: Real-time log viewer with filtering by level
- **Format**: `[timestamp] [level] [file:line] message`

### 5. User Interface (`Views/`)
- **ContentView**: Main interface with sidebar navigation (Home, Rules, Logs)
- **RuleConfigView**: Manage application-specific window rules
- **LogViewer**: Real-time log display with level filtering and search
- **Responsive Design**: Adapts to light/dark mode, proper macOS styling

## Build and Development Commands

### Building
```bash
# Build debug version
swift build

# Build release version
swift build -c release

# Create distributable app bundle
swift build -c release && mkdir -p Release && cp -r .build/release/Maru.app Release/
```

### Running
```bash
# Run from source
swift run

# Run specific build
swift run Maru
```

### Development
```bash
# Open in Xcode for UI development
open Package.swift

# Clean build artifacts
swift package clean
```

## Configuration Files

### Swift Package Manager (`Package.swift`)
- Minimum macOS version: 13.0
- Swift tools version: 5.8
- Executable target: Maru
- Resources: Assets.xcassets
- Excludes: demo.lua, Info.plist

### Configuration Storage
- **Directory**: `~/Library/Application Support/Maru/`
- **App Rules**: `config.json` - Application-specific window handling rules
- **General Settings**: `general.json` - Scale factor, log level preferences
- **Logs**: `Logs/maru_*.log` - Rotating log files

## Code Style Guidelines

### Swift Style
- **Naming**: CamelCase for types, lowerCamelCase for variables/functions
- **Comments**: Use Chinese comments for business logic (matching existing codebase)
- **MARK**: Use `// MARK: -` for section organization
- **Access Control**: Explicit access modifiers (private, internal, public)
- **Error Handling**: Comprehensive error logging with AppLogger

### Architecture Patterns
- **ObservableObject**: Used for state management (AppConfig, AppLogger, WindowManager)
- **EnvironmentObject**: For dependency injection in SwiftUI views
- **Combine**: For reactive programming and state updates
- **NotificationCenter**: For inter-component communication

### Key Conventions
1. **Logging**: Always use `AppLogger.shared.log()` instead of `print()`
2. **Configuration**: Access through `AppConfig.shared` singleton
3. **Window Operations**: Use `WindowManager` for all window manipulations
4. **Permissions**: Check accessibility permissions before window operations
5. **Debouncing**: Apply debouncing to user-triggered actions

## Testing Strategy

### Manual Testing Required
- **Multi-display setups**: Test coordinate conversion on different screen configurations
- **Stage Manager**: Verify compatibility with macOS Stage Manager
- **Accessibility Permissions**: Test permission request flow
- **Various App Types**: Test with different window styles and applications
- **Menu Bar Extra**: Test enable/disable functionality

### Test Areas
1. **Window Detection**: Verify correct window identification across different apps
2. **Rule Application**: Test each rule type (center, almostMaximize, ignore)
3. **Coordinate Conversion**: Validate multi-screen coordinate handling
4. **Configuration Persistence**: Test saving/loading rules and settings
5. **Logging**: Verify log rotation and filtering functionality

## Deployment Process

### Building for Distribution
```bash
# Build release version
swift build -c release

# Create app bundle structure
mkdir -p Release/Applications
cp -r .build/release/Maru.app Release/Applications/

# Create DMG (if needed)
hdiutil create -volname "Maru" -srcfolder Release/Applications -ov -format UDZO Maru.dmg
```

### Code Signing
- Ensure proper code signing for accessibility API usage
- Include permission requests in initial setup
- Test on clean macOS installations

### Permissions Required
1. **Accessibility**: Required for window manipulation using AXUIElement APIs
2. **Screen Recording**: Required for window information access
3. **Automation**: Required for AppleScript window control

## Security Considerations

### Permissions
- App requests accessibility permissions on first launch
- Screen recording permission required for window detection
- All permissions are requested with user consent

### Data Storage
- Configuration stored locally in user's Application Support directory
- No network communication or data transmission
- Logs contain window titles and app names (user data)

### Code Safety
- No external dependencies (dependencies array is empty in Package.swift)
- No network requests
- Sandboxed file operations

## Common Development Tasks

### Adding New Window Rules
1. Update `WindowHandlingRule` enum in `AppConfig.swift`
2. Add handling logic in `WindowManager.manageWindow()`
3. Update UI components in `RuleConfigView` to support new rule type
4. Test with various application types

### Modifying Window Behavior
1. Core logic in `WindowManager.centerWindow()` and `almostMaximizeWindow()`
2. Update coordinate conversion utilities for multi-screen support
3. Adjust debouncing and cooldown timing if needed
4. Update default rules in `AppConfig.setupDefaultRules()`

### UI Changes
1. SwiftUI views in `Sources/Maru/Views/`
2. Support dark mode using `@Environment(\.colorScheme)`
3. Use responsive layout with `GeometryReader`
4. Follow macOS human interface guidelines

### Debugging
1. Use built-in log viewer (accessible via menu bar or Command+Option+L)
2. Monitor logs in real-time during window operations
3. Check accessibility permissions in System Settings
4. Use Console.app for system-level debugging

## Performance Considerations

### Window Management
- Debouncing prevents excessive CPU usage
- Cooldown periods prevent rapid window adjustments
- Efficient coordinate conversion algorithms
- Minimal memory footprint for window state tracking

### Logging
- Asynchronous log writing to prevent UI blocking
- Log rotation prevents disk space issues
- Memory-limited log buffer (1000 entries)

### UI Responsiveness
- SwiftUI ensures smooth UI updates
- Background processing for window operations
- Efficient state management with `@Published` properties

## Troubleshooting

### Common Issues
1. **Window not resizing**: Check accessibility permissions
2. **Wrong window detected**: Verify coordinate conversion logic
3. **App not responding**: Check for infinite loops in window management
4. **Rules not applying**: Verify configuration file persistence

### Debug Steps
1. Open Log Viewer (Command+Option+L)
2. Check accessibility permission status
3. Monitor window detection logs
4. Verify configuration files in Application Support directory

## Additional Resources

- **Original Migration**: Project migrated from Hammerspoon Lua script
- **macOS APIs**: Heavy use of Accessibility API and NSWorkspace
- **SwiftUI**: Modern declarative UI approach
- **Combine**: Reactive programming for state management
