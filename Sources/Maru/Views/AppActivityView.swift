import SwiftUI
import AppKit

struct AppActivityView: View {
    @EnvironmentObject private var activityStore: AppActivityStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedBundleIdentifier: String?
    @State private var appSearchText = ""

    private var state: AppActivityViewState {
        AppActivityViewState(
            events: activityStore.events,
            selectedBundleIdentifier: selectedBundleIdentifier,
            appSearchText: appSearchText
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            pageHeader

            if activityStore.events.isEmpty {
                emptyPage
            } else {
                HStack(alignment: .top, spacing: 16) {
                    appSelector
                        .frame(minWidth: 190, idealWidth: 220, maxWidth: 240)

                    timelineSurface
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 34)
        .padding(.vertical, 30)
        .onAppear(perform: synchronizeSelection)
        .onChange(of: activityStore.events) { _ in
            synchronizeSelection()
        }
        .onChange(of: appSearchText) { _ in
            synchronizeSelection()
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("应用动态")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("按 App 查看 Maru 何时介入、为什么处理或跳过，以及最终执行结果。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            if !activityStore.events.isEmpty {
                Menu {
                    Button(role: .destructive, action: confirmClearActivity) {
                        Label("清除全部动态", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    private var appSelector: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("应用")
                        .font(.headline)

                    Spacer(minLength: 8)

                    Text("\(state.appSummaries.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.secondary.opacity(0.10)))
                }

                TextField("搜索名称或 Bundle ID", text: $appSearchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(16)

            Divider()

            if state.filteredAppSummaries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("没有匹配的 App")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(state.filteredAppSummaries) { app in
                            appRow(app)
                        }
                    }
                    .padding(10)
                }
            }

            Divider()

            Text("动态只保存在本机，最多保留最近 \(AppActivityStore.defaultMaximumEventCount) 条。")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(secondarySurface(cornerRadius: 22))
    }

    private func appRow(_ app: AppActivityAppSummary) -> some View {
        let isSelected = app.bundleIdentifier == selectedBundleIdentifier

        return Button {
            selectedBundleIdentifier = app.bundleIdentifier
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: AppIconProvider.loadApplicationIcon(bundleIdentifier: app.bundleIdentifier, size: 30))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(app.appName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .lineLimit(1)

                    Text("\(app.eventCount) 条 · \(relativeDate(app.lastActivity))")
                        .font(.caption2)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.76) : Color.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var timelineSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineHeader
            Divider()

            if state.selectedEvents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)

                    Text("这个 App 暂时没有动态")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(state.selectedEvents) { event in
                            activityRow(event)

                            if event.id != state.selectedEvents.last?.id {
                                Divider()
                                    .padding(.leading, 112)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(primarySurface(cornerRadius: 22))
    }

    private var timelineHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            if let app = state.selectedAppSummary {
                Image(nsImage: AppIconProvider.loadApplicationIcon(bundleIdentifier: app.bundleIdentifier, size: 36))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(app.appName)
                        .font(.headline)

                    Text(app.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text("\(app.eventCount) 条动态")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func activityRow(_ event: AppActivityEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeText(event.timestamp))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(dateText(event.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 68, alignment: .trailing)

            Image(systemName: event.kind.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(eventColor(event.kind))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(eventColor(event.kind).opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if event.windowTitle != nil || event.trigger != nil {
                    HStack(spacing: 8) {
                        if let windowTitle = event.windowTitle {
                            metadataChip(windowTitle, systemImage: "macwindow")
                        }

                        if let trigger = event.trigger {
                            metadataChip(trigger, systemImage: "bolt")
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func metadataChip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.secondary.opacity(0.08)))
    }

    private var emptyPage: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)

            Text("还没有应用动态")
                .font(.title3)
                .fontWeight(.semibold)

            Text("当 App 启动、进入前台，或 Maru 对窗口执行、跳过操作时，记录会出现在这里。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(primarySurface(cornerRadius: 22))
    }

    private func synchronizeSelection() {
        selectedBundleIdentifier = state.suggestedBundleIdentifier
    }

    private func confirmClearActivity() {
        let alert = NSAlert()
        alert.messageText = "清除全部应用动态？"
        alert.informativeText = "所有按 App 保存的排查记录都会从本机删除，此操作无法撤销。后台日志不会受到影响。"
        alert.addButton(withTitle: "清除")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            activityStore.clearEvents()
        }
    }

    private func eventColor(_ kind: AppActivityEventKind) -> Color {
        switch kind {
        case .launched, .activated, .window, .action:
            return .blue
        case .success:
            return .green
        case .skipped:
            return .orange
        case .failure:
            return .red
        }
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
    }

    private func relativeDate(_ date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    private func primarySurface(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.blue.opacity(0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.10), lineWidth: 1)
            )
    }

    private func secondarySurface(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12), lineWidth: 1)
            )
    }
}
