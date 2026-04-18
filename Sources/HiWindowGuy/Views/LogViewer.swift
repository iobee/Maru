import SwiftUI

struct LogViewer: View {
    @ObservedObject private var logger = AppLogger.shared
    @State private var logLevelFilter: LogLevel? = .info
    @State private var selectedLogFile: URL?
    @State private var showingFileSelector = false
    @State private var logFiles: [URL] = []
    @Environment(\.colorScheme) private var colorScheme

    private var filteredLogs: [LogEntry] {
        var logs = logger.logs

        if let level = logLevelFilter {
            logs = logs.filter { $0.level.priority >= level.priority }
        }

        return logs.reversed()
    }

    private var logTextContent: String {
        filteredLogs.map(\.formatted).joined(separator: "\n")
    }

    private var subtitleText: String {
        if filteredLogs.isEmpty {
            return "查看运行日志、导出当前内容，或载入历史日志文件。"
        }

        return "当前显示 \(filteredLogs.count) 条日志记录，可按级别筛选并导出。"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader
                toolRow
                logSurface
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .sheet(isPresented: $showingFileSelector) {
            LogFileSelector(logFiles: logFiles, selectedFile: $selectedLogFile, isPresented: $showingFileSelector)
                .frame(minWidth: 480, idealWidth: 540, maxWidth: 620, minHeight: 380, idealHeight: 480, maxHeight: 580)
        }
        .onChange(of: selectedLogFile) { file in
            if let file = file {
                loadLogsFromFile(file)
            }
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日志")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text(subtitleText)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var toolRow: some View {
        HStack(spacing: 12) {
            filterMenu

            Spacer(minLength: 16)

            Button {
                showingFileSelector = true
                loadLogFiles()
            } label: {
                Label("历史日志", systemImage: "folder")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(toolButtonBackground)
            }
            .buttonStyle(.plain)

            Button {
                confirmClearLogs()
            } label: {
                Label("清空", systemImage: "trash")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(toolButtonBackground)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(secondarySurfaceBackground(cornerRadius: 18))
    }

    private var filterMenu: some View {
        Menu {
            Button {
                logLevelFilter = nil
            } label: {
                Label("全部级别", systemImage: logLevelFilter == nil ? "checkmark" : "line.3.horizontal.decrease.circle")
            }

            ForEach(LogLevel.allCases) { level in
                Button {
                    logLevelFilter = level
                } label: {
                    Label(level.rawValue, systemImage: logLevelFilter == level ? "checkmark" : level.icon)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 12, weight: .semibold))

                Text("级别：\(logLevelFilter?.rawValue ?? "全部")")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(toolButtonBackground)
        }
        .buttonStyle(.plain)
    }

    private var logSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            if filteredLogs.isEmpty {
                emptyStateView
            } else {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(logTextContent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .padding(20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .overlay(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12))

            bottomStatusBar
        }
        .background(primarySurfaceBackground(cornerRadius: 22))
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text("当前没有可显示的日志")
                .font(.headline)
                .foregroundStyle(.primary)

            if logLevelFilter != nil {
                Text("试试切换到更低日志级别，或者载入历史日志文件。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    logLevelFilter = nil
                } label: {
                    Text("显示全部级别")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            } else {
                Text("应用运行期间产生的日志会集中显示在这里。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 52)
    }

    private var bottomStatusBar: some View {
        HStack(spacing: 12) {
            Label("\(filteredLogs.count) 条日志", systemImage: "doc.text")
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Spacer(minLength: 16)

            Button {
                exportLogs()
            } label: {
                Label("导出日志", systemImage: "square.and.arrow.up")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(toolButtonBackground)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var toolButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(colorScheme == .dark ? 0.05 : 0.55))
    }

    private func primarySurfaceBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.blue.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.10), lineWidth: 1)
            )
    }

    private func secondarySurfaceBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(colorScheme == .dark ? 0.02 : 0.38))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12), lineWidth: 1)
            )
    }

    private func confirmClearLogs() {
        let alert = NSAlert()
        alert.messageText = "确认清除当前日志吗？"
        alert.informativeText = "此操作无法撤销。清除后，日志将从界面中移除，但日志文件仍会保留。"
        alert.addButton(withTitle: "确认清除")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            logger.clearLogs()
        }
    }

    private func loadLogFiles() {
        logFiles = AppLogger.shared.getLogFiles()
    }

    private func loadLogsFromFile(_ file: URL) {
        let entries = AppLogger.shared.loadLogFile(file)
        DispatchQueue.main.async {
            AppLogger.shared.logs = entries
        }
    }

    private func exportLogs() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("hiwindowguy_logs_\(timestamp).log")

        var logContent = ""
        for entry in filteredLogs.reversed() {
            logContent += entry.formatted + "\n"
        }

        do {
            try logContent.write(to: fileURL, atomically: true, encoding: .utf8)

            let panel = NSSavePanel()
            panel.nameFieldStringValue = fileURL.lastPathComponent
            panel.allowedContentTypes = [.log, .text]
            panel.canCreateDirectories = true

            panel.begin { response in
                if response == .OK, let url = panel.url {
                    do {
                        try FileManager.default.moveItem(at: fileURL, to: url)
                        AppLogger.shared.log("日志已导出到: \(url.path)", level: .info)
                    } catch {
                        AppLogger.shared.log("导出日志失败: \(error.localizedDescription)", level: .error)
                    }
                }
            }
        } catch {
            AppLogger.shared.log("导出日志失败: \(error.localizedDescription)", level: .error)
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
                    VStack(spacing: 12) {
                        ForEach(logFiles, id: \.self) { file in
                            LogFileRow(file: file)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedFile = file
                                    isPresented = false
                                }
                        }
                    }
                    .padding(24)
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

                Text("选择一个日志文件载入当前查看器。")
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
        .background(
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(Rectangle().fill(Color.white.opacity(colorScheme == .dark ? 0.04 : 0.10)))
        )
    }

    private var footer: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Text("取消")
                    .frame(width: 100)
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 16)

            Text("\(logFiles.count) 个日志文件")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            Rectangle()
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(Rectangle().fill(Color.white.opacity(colorScheme == .dark ? 0.04 : 0.10)))
        )
    }
}

struct LogFileRow: View {
    let file: URL
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.10))

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)

                Text("创建于：\(formattedDate(for: file))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            Text(formattedFileSize(for: file))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.45))
                )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12), lineWidth: 1)
                )
        )
    }

    private func formattedDate(for file: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            if let date = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter.string(from: date)
            }
        } catch {
            print("获取文件日期失败: \(error)")
        }
        return "未知日期"
    }

    private func formattedFileSize(for file: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            if let size = attributes[.size] as? NSNumber {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: size.int64Value)
            }
        } catch {
            print("获取文件大小失败: \(error)")
        }
        return "未知大小"
    }
}
