import SwiftUI

struct LogViewer: View {
    @ObservedObject private var logger = AppLogger.shared
    @State private var logLevelFilter: LogLevel? = .info // 默认显示Info及以上级别
    @State private var searchText = ""
    @State private var selectedLogFile: URL?
    @State private var showingFileSelector = false
    @State private var logFiles: [URL] = []
    @Environment(\.colorScheme) private var colorScheme
    
    private var filteredLogs: [LogEntry] {
        var logs = logger.logs
        
        // 过滤日志级别
        if let level = logLevelFilter {
            logs = logs.filter { $0.level.priority >= level.priority }
        }
        
        // 搜索过滤
        if !searchText.isEmpty {
            logs = logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) || $0.sourceFile.localizedCaseInsensitiveContains(searchText) }
        }
        
        return logs.reversed() // 反转数组，最新日志在顶部
    }
    
    // 页面标题区域
    private var headerView: some View {
        HStack(spacing: 0) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
            VStack(alignment: .leading, spacing: 4) {
                Text("应用日志")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    
                Text("查看和管理应用运行日志")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 12)
            
            Spacer()
            
            // 日志级别过滤器
            Picker("日志级别", selection: $logLevelFilter) {
                Text("全部级别").tag(nil as LogLevel?)
                ForEach(LogLevel.allCases) { level in
                    Label(level.rawValue, systemImage: level.icon)
                        .tag(level as LogLevel?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(width: 130)
            .padding(.horizontal, 8)
            
            // 历史日志按钮
            Button {
                showingFileSelector = true
                loadLogFiles()
            } label: {
                Label("历史日志", systemImage: "folder")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Material.regularMaterial)
                    )
            }
            .buttonStyle(.plain)
            
            // 清空日志按钮
            Button {
                confirmClearLogs()
            } label: {
                Label("清空", systemImage: "trash")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Material.regularMaterial)
                    )
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 20)
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            
            Text("没有找到匹配的日志记录")
                .font(.headline)
                .foregroundStyle(.primary)
                
            if !searchText.isEmpty {
                Text("尝试使用不同的搜索关键词或调整日志级别")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    
                Button {
                    searchText = ""
                } label: {
                    Text("清除搜索")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            } else if logLevelFilter != nil {
                Text("尝试调整日志级别过滤器或加载历史日志")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    
                Button {
                    logLevelFilter = nil
                } label: {
                    Text("显示全部日志级别")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            } else {
                Text("应用运行期间的日志将显示在这里")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题区域
            headerView
            
            // 搜索栏
            SearchBar(text: $searchText, placeholder: "搜索日志内容或文件名")
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            
            // 日志列表
            if filteredLogs.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredLogs) { logEntry in
                            LogEntryRow(entry: logEntry)
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 16)
                }
                .background(Color.clear)
                .safeAreaInset(edge: .bottom) {
                    bottomStatusBar
                }
            }
        }
        .background(Color.clear)
        .sheet(isPresented: $showingFileSelector) {
            LogFileSelector(logFiles: logFiles, selectedFile: $selectedLogFile, isPresented: $showingFileSelector)
                .frame(minWidth: 450, idealWidth: 500, maxWidth: 600, minHeight: 350, idealHeight: 450, maxHeight: 550)
        }
        .onChange(of: selectedLogFile) { file in
            if let file = file {
                loadLogsFromFile(file)
            }
        }
    }
    
    // 底部状态栏
    private var bottomStatusBar: some View {
        HStack {
            Label("\(filteredLogs.count) 条日志", systemImage: "doc.text")
                .foregroundStyle(.secondary)
                .font(.footnote.bold())
            
            Spacer()
            
            Button {
                exportLogs()
            } label: {
                Label("导出日志", systemImage: "square.and.arrow.up")
                    .font(.footnote.bold())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Material.thin)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 14)
        .background(
            Rectangle()
                .fill(Material.thin)
                .shadow(color: .black.opacity(0.05), radius: 5, y: -2)
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
        for entry in filteredLogs.reversed() { // 导出时保持时间顺序
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

struct LogEntryRow: View {
    let entry: LogEntry
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: entry.level.icon)
                    .foregroundColor(logLevelColor(entry.level))
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 24, height: 24)
                    .background(logLevelColor(entry.level).opacity(0.1))
                    .clipShape(Circle())
                
                Text(entry.formattedTimestamp)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                
                Text(entry.message)
                    .lineLimit(isExpanded ? nil : 1)
                    .font(.callout)
                
                Spacer()
                
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            if isExpanded {
                HStack(spacing: 16) {
                    Label("\(entry.sourceFile):\(entry.sourceLine)", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label(entry.level.rawValue, systemImage: "tag")
                        .font(.caption)
                        .foregroundColor(logLevelColor(entry.level))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(logLevelColor(entry.level).opacity(0.1))
                        )
                }
                .padding(.leading, 28)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Material.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
    
    private func logLevelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug:
            return .secondary
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
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
            // 标题栏
            HStack {
                Text("选择历史日志文件")
                    .font(.title3.bold())
                
                Spacer()
                
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Material.bar)
                
            // 文件列表
            if logFiles.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                    
                    Text("没有发现日志文件")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        
                    Text("运行应用后生成的日志文件将显示在这里")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
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
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            
            // 底部按钮
            HStack {
                Button {
                    isPresented = false
                } label: {
                    Text("取消")
                        .frame(width: 100)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Text("\(logFiles.count) 个日志文件")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Material.bar)
        }
    }
}

struct LogFileRow: View {
    let file: URL
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.blue)
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("创建于: \(formattedDate(for: file))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formattedFileSize(for: file))
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Material.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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