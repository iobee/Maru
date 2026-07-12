import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LogViewer: View {
    @ObservedObject private var logger = AppLogger.shared
    @State private var minimumLevel: LogLevel? = .info
    @State private var searchText = ""
    @State private var selectedLogFile: URL?
    @State private var showingFileSelector = false
    @State private var logFiles: [URL] = []
    @State private var loadedHistoricalLogs: [LogEntry]?
    @State private var loadedFileName: String?
    @State private var copyFeedback: String?
    @Environment(\.colorScheme) private var colorScheme

    private var sourceLogs: [LogEntry] {
        loadedHistoricalLogs ?? logger.logs
    }

    private var state: BackgroundLogViewState {
        BackgroundLogViewState(
            logs: sourceLogs,
            minimumLevel: minimumLevel,
            searchText: searchText
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            pageHeader
            toolRow
            logSurface
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 34)
        .padding(.vertical, 30)
        .sheet(isPresented: $showingFileSelector) {
            LogFileSelector(
                logFiles: logFiles,
                selectedFile: $selectedLogFile,
                isPresented: $showingFileSelector
            )
            .frame(
                minWidth: 480,
                idealWidth: 540,
                maxWidth: 620,
                minHeight: 380,
                idealHeight: 480,
                maxHeight: 580
            )
        }
        .onChange(of: selectedLogFile) { file in
            guard let file else { return }
            loadLogsFromFile(file)
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("后台日志")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("供开发者排查问题使用。遇到异常时，可直接复制或导出完整日志发送给开发者。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            Label(logSourceTitle, systemImage: loadedHistoricalLogs == nil ? "dot.radiowaves.left.and.right" : "doc.text")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.secondary.opacity(0.09)))
        }
    }

    private var toolRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                searchField
                filterMenu
                Spacer(minLength: 12)
                logActionButtons
            }

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    searchField
                    filterMenu
                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    Spacer(minLength: 0)
                    logActionButtons
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(secondarySurfaceBackground(cornerRadius: 18))
    }

    private var logActionButtons: some View {
        HStack(spacing: 10) {
            Button(action: copyCompleteLogs) {
                Label("复制日志", systemImage: "doc.on.doc")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(toolButtonBackground)
            }
            .buttonStyle(.plain)
            .disabled(sourceLogs.isEmpty)

            Button(action: exportCompleteLogs) {
                Label("导出", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(toolButtonBackground)
            }
            .buttonStyle(.plain)
            .disabled(sourceLogs.isEmpty)

            moreMenu
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("搜索消息或源码位置", text: $searchText)
                .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(minWidth: 180, idealWidth: 240, maxWidth: 280, minHeight: 34)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(colorScheme == .dark ? 0.55 : 0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var filterMenu: some View {
        Menu {
            Button {
                minimumLevel = nil
            } label: {
                Label("全部级别", systemImage: minimumLevel == nil ? "checkmark" : "line.3.horizontal.decrease.circle")
            }

            ForEach(LogLevel.allCases) { level in
                Button {
                    minimumLevel = level
                } label: {
                    Label("\(level.rawValue)及以上", systemImage: minimumLevel == level ? "checkmark" : level.icon)
                }
            }
        } label: {
            Label(filterTitle, systemImage: "line.3.horizontal.decrease.circle")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(toolButtonBackground)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var moreMenu: some View {
        Menu {
            Button {
                loadLogFiles()
                showingFileSelector = true
            } label: {
                Label("查看历史日志", systemImage: "folder")
            }

            if loadedHistoricalLogs != nil {
                Button(action: returnToLiveLogs) {
                    Label("返回实时日志", systemImage: "dot.radiowaves.left.and.right")
                }
            } else {
                Divider()

                Button(role: .destructive, action: confirmClearLogs) {
                    Label("清空当前内存日志", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 34, height: 34)
                .background(toolButtonBackground)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var logSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            if state.filteredLogs.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(state.filteredLogs) { entry in
                            logRow(entry)

                            if entry.id != state.filteredLogs.last?.id {
                                Divider()
                                    .padding(.leading, 184)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()
            bottomStatusBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(primarySurfaceBackground(cornerRadius: 22))
    }

    private func logRow(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(logTime(entry.timestamp))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(logDate(entry.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 78, alignment: .trailing)

            Label(entry.level.rawValue, systemImage: entry.level.icon)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(levelColor(entry.level))
                .frame(width: 66, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.message)
                    .font(.system(size: 12.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(entry.sourceFile):\(entry.sourceLine)")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text(sourceLogs.isEmpty ? "当前没有后台日志" : "没有符合筛选条件的日志")
                .font(.headline)

            Text(sourceLogs.isEmpty
                ? "应用运行期间产生的技术日志会显示在这里。"
                : "可以清除搜索条件，或降低日志级别后再查看。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !sourceLogs.isEmpty {
                Button("重置筛选") {
                    searchText = ""
                    minimumLevel = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var bottomStatusBar: some View {
        HStack(spacing: 10) {
            Label("显示 \(state.filteredLogs.count) / \(sourceLogs.count) 条", systemImage: "doc.text")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            if let copyFeedback {
                Label(copyFeedback, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }

            Spacer(minLength: 12)

            Text("复制与导出始终包含当前来源的完整日志")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var logSourceTitle: String {
        loadedFileName ?? "实时日志"
    }

    private var filterTitle: String {
        minimumLevel.map { "\($0.rawValue)及以上" } ?? "全部级别"
    }

    private var toolButtonBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(colorScheme == .dark ? 0.055 : 0.58))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.08), lineWidth: 1)
            )
    }

    private func primarySurfaceBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.blue.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.09), lineWidth: 1)
            )
    }

    private func secondarySurfaceBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12), lineWidth: 1)
            )
    }

    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .secondary
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func logTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
    }

    private func logDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
    }

    private func copyCompleteLogs() {
        guard !state.completeLogText.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(state.completeLogText, forType: .string)
        showCopyFeedback("已复制 \(sourceLogs.count) 条")
    }

    private func showCopyFeedback(_ message: String) {
        copyFeedback = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if copyFeedback == message {
                copyFeedback = nil
            }
        }
    }

    private func loadLogFiles() {
        logFiles = logger.getLogFiles()
    }

    private func loadLogsFromFile(_ file: URL) {
        loadedHistoricalLogs = logger.loadLogFile(file)
        loadedFileName = file.lastPathComponent
        searchText = ""
        selectedLogFile = nil
    }

    private func returnToLiveLogs() {
        loadedHistoricalLogs = nil
        loadedFileName = nil
        selectedLogFile = nil
        searchText = ""
    }

    private func confirmClearLogs() {
        let alert = NSAlert()
        alert.messageText = "清空当前内存日志？"
        alert.informativeText = "界面中的实时日志会被清空，磁盘上的历史日志文件不会删除。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            logger.clearLogs()
        }
    }

    private func exportCompleteLogs() {
        guard !state.completeLogText.isEmpty else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let defaultName = "maru_logs_\(formatter.string(from: Date())).log"
        let content = state.completeLogText + "\n"

        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.log, .plainText]
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                AppLogger.shared.log("日志已导出到: \(url.path)", level: .info)
            } catch {
                AppLogger.shared.log("导出日志失败: \(error.localizedDescription)", level: .error)
            }
        }
    }
}

struct LogFileSelector: View {
    let logFiles: [URL]
    @Binding var selectedFile: URL?
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            header

            if logFiles.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "folder")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)

                    Text("没有发现历史日志")
                        .font(.headline)

                    Text("运行应用后生成的日志文件会显示在这里。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(logFiles, id: \.self) { file in
                            LogFileRow(file: file)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedFile = file
                                    isPresented = false
                                }
                        }
                    }
                    .padding(20)
                }
            }

            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("历史日志")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("载入查看不会覆盖或中断当前实时日志。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(headerFooterBackground)
    }

    private var footer: some View {
        HStack {
            Text("\(logFiles.count) 个日志文件")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            Button("取消") {
                isPresented = false
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(headerFooterBackground)
    }

    private var headerFooterBackground: some View {
        Rectangle()
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(Rectangle().fill(Color.white.opacity(colorScheme == .dark ? 0.04 : 0.10)))
    }
}

struct LogFileRow: View {
    let file: URL
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(file.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)

                Text("创建于 \(formattedDate(for: file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Text(formattedFileSize(for: file))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12), lineWidth: 1)
                )
        )
    }

    private func formattedDate(for file: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              let date = attributes[.creationDate] as? Date else {
            return "未知日期"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func formattedFileSize(for file: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              let size = attributes[.size] as? NSNumber else {
            return "未知大小"
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size.int64Value)
    }
}
