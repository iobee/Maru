# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Maru is a macOS open-source window utility written in Swift using SwiftUI. It automatically moves windows to the center of the screen so the desktop stays clean, balanced, and easy to use.

Product copy:
- Name: Maru
- Slogan: Center it beautifully.
- Chinese slogan: 一键居中，让日常更优雅。
- One-line description: Maru 是一款 macOS 开源工具，可自动将窗口优雅地移动到屏幕中央，让桌面始终简洁、平衡、顺手。

## Architecture

### Core Components

- **MaruApp.swift**: Main app entry point using SwiftUI App protocol
  - Manages menu bar extra, window configuration, and global app state
  - Handles accessibility permissions and app lifecycle
  - Configures window appearance (hidden title bar, transparency)

- **WindowManager.swift**: Core window management engine
  - Monitors application focus changes using NSWorkspace notifications
  - Implements debouncing to prevent rapid window adjustments
  - Uses Accessibility APIs (AXUIElement) for window manipulation
  - Handles multi-screen coordinate system conversions
  - Supports Stage Manager and various macOS windowing modes

- **AppConfig.swift**: Configuration and state management
  - Manages per-application window handling rules (center, almost maximize, ignore)
  - Stores window scaling factor and app preferences
  - Implements JSON persistence for configuration data

- **Views/**: SwiftUI interface components
  - ContentView: Main app interface with sidebar navigation
  - RuleConfigView: Interface for managing application-specific rules
  - LogViewer: Real-time log display with filtering
  - SidebarView: Navigation sidebar with status indicators

### Window Management System

The app uses a sophisticated window detection and management system:

1. **Detection**: Uses mouse position and geometric matching to find the target window
2. **Rules**: Applies different behaviors based on application type:
   - Message apps (WeChat, Messages): Center positioning
   - General apps: Almost maximize with configurable scaling
   - Specific apps: Ignore handling
3. **Multi-screen**: Handles multiple displays with proper coordinate conversion
4. **Safety**: Implements cooldown periods and operation flags to prevent conflicts

## Build and Development Commands

### Building

```bash
# Build the project
swift build

# Build for release
swift build -c release

# Create distributable app
swift build -c release && mkdir -p Release && cp -r .build/release/Maru.app Release/
```

### Running

```bash
# Run from source
swift run

# Run specific build
swift run Maru
```

### Development Workflow

- Use Xcode for UI development: `open Package.swift`
- Test accessibility permissions during development
- Monitor logs in the app's Log Viewer for debugging
- Use menu bar extra for quick enable/disable testing

## Key Technical Details

### Permissions Required

- **Accessibility**: Required for window manipulation using AXUIElement APIs
- **Screen Recording**: Required for window information access

### Coordinate System Handling

The app handles complex coordinate system conversions between:
- NSScreen coordinates (origin at bottom-left, Y-axis up)
- AXUIElement coordinates (origin at top-left, Y-axis down)
- Multi-display setups with different resolutions

### Configuration Storage

- Application support directory: `~/Library/Application Support/Maru/`
- config.json: Application-specific rules
- general.json: General settings (scale factor, log level)

### Debugging and Logging

- Comprehensive logging system with configurable levels
- Real-time log viewer in the app interface
- Detailed window detection and manipulation logging
- Error handling for accessibility API failures

## Common Development Tasks

### Adding New Window Rules

1. Update `WindowHandlingRule` enum in AppConfig.swift
2. Add handling logic in WindowManager.manageWindow()
3. Update UI components to support new rule type

### Modifying Window Behavior

1. Core logic in WindowManager centerWindow() and almostMaximizeWindow()
2. Coordinate conversion utilities for multi-screen support
3. Enhanced frame setting with verification

### UI Changes

1. SwiftUI views in Sources/Maru/Views/
2. Dark mode support using colorScheme environment
3. Responsive layout with GeometryReader

## Testing Notes

- Test on multiple display configurations
- Verify Stage Manager compatibility
- Test with various application window types
- Check accessibility permission handling
- Validate coordinate conversions on different screen setups

## Deployment

The app creates a menu bar extra and runs in the background. When distributing:
- Ensure proper code signing for accessibility APIs
- Include permission requests in initial setup
- Test on clean macOS installations
