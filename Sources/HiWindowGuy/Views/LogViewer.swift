import SwiftUI

struct LogViewer: View {
    @ObservedObject private var logger = AppLogger.shared
    @State private var logLevelFilter: LogLevel? = .info // 默认显示Info及以上级别
    @State private var searchText = ""
    @State private var selectedLogFile: URL?
    @State private var showingFileSelector = false
    @State private var logFiles: [URL] = []
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("系统日志")
                    .font(.title2.bold())
                
                Spacer()
                
                Button {
                    showingFileSelector = true
                    loadLogFiles()
                } label: {
                    Label("历史日志", systemImage: "folder")
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 8)
                
                Divider()
                    .frame(height: 15)
                    .padding(.horizontal, 4)
                
                Button {
                    confirmClearLogs()
                } label: {
                    Label("清空", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
            .padding()
            .background(Material.bar)
            
            HStack {
                SearchBar(text: $searchText, placeholder: "搜索日志内容或文件名")
                    .frame(maxWidth: .infinity)
                
                Picker("日志级别", selection: $logLevelFilter) {
                    Text("全部").tag(nil as LogLevel?)
                    ForEach(LogLevel.allCases) { level in
                        HStack {
                            Image(systemName: level.icon)
                            Text(level.rawValue)
                        }
                        .tag(level as LogLevel?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 120)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Material.ultraThinMaterial)
            
            Divider()
            
            List {
                ForEach(filteredLogs) { logEntry in
                    LogEntryRow(entry: logEntry)
                }
            }
            .listStyle(PlainListStyle())
            .background(Material.ultraThinMaterial)
            
            Divider()
            
            HStack {
                Text("共 \(filteredLogs.count) 条日志")
                    .foregroundColor(.secondary)
                    .font(.footnote)
                
                Spacer()
                
                Button {
                    exportLogs()
                } label: {
                    Label("导出当前日志", systemImage: "square.and.arrow.up")
                }
                .font(.footnote)
            }
            .padding()
            .background(Material.thin)
        }
        .background(Color.clear)
        .frame(minWidth: 550, idealWidth: 700, maxWidth: 1000, minHeight: 400, idealHeight: 500, maxHeight: 800)
        .sheet(isPresented: $showingFileSelector) {
            LogFileSelector(logFiles: logFiles, selectedFile: $selectedLogFile, isPresented: $showingFileSelector)
                .frame(minWidth: 400, idealWidth: 450, maxWidth: 500, minHeight: 300, idealHeight: 400, maxHeight: 500)
        }
        .onChange(of: selectedLogFile) { file in
            if let file = file {
                loadLogsFromFile(file)
            }
        }
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
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entry.level.icon)
                    .foregroundColor(logLevelColor(entry.level))
                    .font(.system(size: 12, weight: .semibold))
                
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
                }
                .buttonStyle(PlainButtonStyle())
                .font(.caption)
                .foregroundColor(.secondary)
                .contentShape(Rectangle())
            }
            
            if isExpanded {
                HStack {
                    Label("\(entry.sourceFile):\(entry.sourceLine)", systemImage: "doc.text")
                    Spacer()
                    Label(entry.level.rawValue, systemImage: "tag")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.leading, 20) // 缩进详细信息
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? 
                     Color.black.opacity(0.1) : 
                     Color.white.opacity(0.3))
                .opacity(isExpanded ? 1 : 0)
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
    
    var body: some View {
        VStack(spacing: 0) {
            Text("选择历史日志文件")
                .font(.title3.weight(.semibold))
                .padding()
                
            Divider()
            
            if logFiles.isEmpty {
                VStack {
                    Spacer()
                    Text("没有发现日志文件")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(logFiles, id: \.self) { file in
                        LogFileRow(file: file)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedFile = file
                                isPresented = false
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
            
            Divider()
            
            HStack {
                Button("取消") {
                    isPresented = false
                }
                
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

struct LogFileRow: View {
    let file: URL
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("创建于: \(formattedDate(for: file))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formattedFileSize(for: file))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.vertical, 8)
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