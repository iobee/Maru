import AppKit
import SwiftUI

struct ManualControlView: View {
    @EnvironmentObject private var appConfig: AppConfig
    @State private var editingShortcutAction: ManualWindowAction?
    @State private var shortcutDraft: ShortcutBinding?
    @State private var shortcutValidationWarning: String?

    private var shortcutItems: [ShortcutItem] {
        [
            ShortcutItem(
                action: .center,
                title: ManualWindowAction.center.label,
                description: "将当前前台应用的活动标准窗口移动到屏幕中央。",
                currentBinding: appConfig.manualCenterShortcut,
                defaultBinding: ManualWindowAction.center.defaultShortcut
            ),
            ShortcutItem(
                action: .almostMaximize,
                title: ManualWindowAction.almostMaximize.label,
                description: "将当前前台应用的活动标准窗口调整为接近满屏的工作尺寸。",
                currentBinding: appConfig.manualAlmostMaximizeShortcut,
                defaultBinding: ManualWindowAction.almostMaximize.defaultShortcut
            )
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader
                manualOverviewCard
                shortcutSettingsCard
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
    }
}

private extension ManualControlView {
    struct ShortcutItem: Identifiable {
        let action: ManualWindowAction
        let title: String
        let description: String
        let currentBinding: ShortcutBinding?
        let defaultBinding: ShortcutBinding

        var id: ManualWindowAction { action }

        var currentBindingText: String {
            currentBinding?.displayText ?? "未设置"
        }
    }

    var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手动控制")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("通过全局快捷键和菜单主动整理窗口。手动操作始终作用于当前前台应用的活动标准窗口，不会复用鼠标优先选窗逻辑。")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var manualOverviewCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("手动窗口操作", systemImage: "keyboard")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 10) {
                Text("通过快捷键和菜单主动整理窗口")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("适合在自动规则之外临时整理当前工作区。手动操作会直接面向前台应用的活动标准窗口，并在找不到可操作窗口时给出提示。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                overviewRow(
                    icon: "scope",
                    title: "作用目标",
                    detail: "当前前台应用的活动标准窗口"
                )
                overviewRow(
                    icon: "menubar.arrow.up.rectangle",
                    title: "触发入口",
                    detail: "全局快捷键、菜单栏、窗口管理菜单"
                )
                overviewRow(
                    icon: "exclamationmark.bubble",
                    title: "失败反馈",
                    detail: "找不到可操作窗口时会直接提示"
                )
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(overviewCardBackground)
    }

    func overviewRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.blue.opacity(0.08))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    var shortcutSettingsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("快捷键设置")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("为手动窗口操作分配组合键，当前绑定会同时作用于菜单栏和“窗口管理”菜单。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(shortcutItems) { item in
                    shortcutRow(for: item)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(standardCardBackground(cornerRadius: 22))
    }

    func shortcutRow(for item: ShortcutItem) -> some View {
        let isEditing = editingShortcutAction == item.action
        let duplicateWarning = shortcutDuplicateWarning(for: item.action, draft: shortcutDraft)
        let validationWarning = shortcutValidationWarning
        let draftText = formattedBindingText(shortcutDraft?.displayText ?? "等待输入")

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)

                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 18)

                VStack(alignment: .trailing, spacing: 7) {
                    Text("当前快捷键")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(formattedBindingText(item.currentBindingText))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(item.currentBinding == nil ? .secondary : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.94))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.blue.opacity(item.currentBinding == nil ? 0.08 : 0.12), lineWidth: 1)
                        )
                }
            }

            HStack(alignment: .center, spacing: 12) {
                Text("默认 \(formattedBindingText(item.defaultBinding.displayText))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Button(isEditing ? "录入中" : "修改") {
                        beginRecordingShortcut(for: item.action)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isEditing)

                    Button("清除") {
                        clearShortcut(for: item.action)
                    }
                    .disabled(item.currentBinding == nil)

                    Button("恢复默认") {
                        restoreDefaultShortcut(for: item.action)
                    }
                    .disabled(item.currentBinding == item.defaultBinding)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if isEditing {
                shortcutRecordingStrip(
                    draftText: draftText,
                    warningText: duplicateWarning ?? validationWarning
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shortcutItemBackground(isEditing: isEditing))
        .animation(.default, value: editingShortcutAction)
        .animation(.default, value: shortcutDraft?.displayText)
    }

    func shortcutRecordingStrip(
        draftText: String,
        warningText: String?
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("录制新的组合键")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("Esc 取消。录入后会立即保存，不支持的按键和重复绑定会在这里提示。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let warningText {
                    Label(warningText, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            Text(draftText)
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.20), lineWidth: 1)
                )

            ShortcutCaptureView(
                isRecording: true,
                onCapture: { binding in
                    handleCapturedShortcut(binding)
                },
                onCancel: {
                    cancelShortcutRecording()
                }
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)

            Button("取消") {
                cancelShortcutRecording()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.blue.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.14), lineWidth: 1)
        )
    }

    func beginRecordingShortcut(for action: ManualWindowAction) {
        editingShortcutAction = action
        shortcutDraft = nil
        shortcutValidationWarning = nil
    }

    func cancelShortcutRecording() {
        editingShortcutAction = nil
        shortcutDraft = nil
        shortcutValidationWarning = nil
    }

    func clearShortcut(for action: ManualWindowAction) {
        appConfig.clearManualShortcut(for: action)
        if editingShortcutAction == action {
            cancelShortcutRecording()
        }
    }

    func restoreDefaultShortcut(for action: ManualWindowAction) {
        appConfig.resetManualShortcut(for: action)
        if editingShortcutAction == action {
            cancelShortcutRecording()
        }
    }

    func handleCapturedShortcut(_ binding: ShortcutBinding?) {
        guard let binding else {
            return
        }

        shortcutDraft = binding
        shortcutValidationWarning = nil

        guard AppConfig.supportsManualShortcut(binding) else {
            shortcutValidationWarning = "该按键不支持注册为全局快捷键。"
            return
        }

        guard let action = editingShortcutAction else {
            return
        }

        guard shortcutDuplicateWarning(for: action, draft: binding) == nil else {
            shortcutValidationWarning = "该组合键已被另一项占用。"
            return
        }

        let saved = appConfig.updateManualShortcut(for: action, binding: binding)
        if saved {
            cancelShortcutRecording()
        } else {
            shortcutValidationWarning = "快捷键保存失败，请重新选择组合键。"
        }
    }

    func shortcutDuplicateWarning(for action: ManualWindowAction, draft: ShortcutBinding?) -> String? {
        guard let draft else {
            return nil
        }

        for item in shortcutItems where item.action != action {
            if item.currentBinding == draft {
                return "该组合键已被“\(item.title)”占用。"
            }
        }

        return nil
    }

    var overviewCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.12), lineWidth: 1)
            )
    }

    func shortcutItemBackground(isEditing: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.blue.opacity(isEditing ? 0.045 : 0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.blue.opacity(isEditing ? 0.16 : 0.08), lineWidth: 1)
            )
    }

    func formattedBindingText(_ text: String) -> String {
        text.replacingOccurrences(of: "+", with: " + ")
    }

    func standardCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.blue.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.10), lineWidth: 1)
            )
    }
}

private struct ShortcutCaptureView: NSViewRepresentable {
    let isRecording: Bool
    let onCapture: (ShortcutBinding?) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutCaptureNSView {
        let view = ShortcutCaptureNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        view.isRecording = isRecording
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        nsView.isRecording = isRecording
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class ShortcutCaptureNSView: NSView {
    var isRecording = false
    var onCapture: ((ShortcutBinding?) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if isRecording {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        if event.keyCode == 53 {
            onCancel?()
            return
        }

        if let binding = ShortcutBinding(event: event) {
            onCapture?(binding)
        } else {
            NSSound.beep()
        }
    }
}

private extension ShortcutBinding {
    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.control, .command, .option, .shift])
        guard !modifiers.isEmpty else {
            return nil
        }

        guard let key = event.charactersIgnoringModifiers?.lowercased(), key.count == 1 else {
            return nil
        }

        self.init(key: key, modifierFlags: modifiers)
    }
}
