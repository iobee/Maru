import Foundation
import Combine

// 日志级别枚举
enum LogLevel: String, Codable, CaseIterable, Identifiable {
    case debug = "调试"
    case info = "信息"
    case warning = "警告"
    case error = "错误"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .debug: return "ladybug"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }
    
    var color: String {
        switch self {
        case .debug: return "gray"
        case .info: return "blue"
        case .warning: return "orange"
        case .error: return "red"
        }
    }
    
    // 日志级别的优先级
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }
}

// 日志条目结构体
struct LogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let message: String
    let level: LogLevel
    let sourceFile: String
    let sourceLine: Int
    
    init(message: String, level: LogLevel, sourceFile: String = #file, sourceLine: Int = #line) {
        self.id = UUID()
        self.timestamp = Date()
        self.message = message
        self.level = level
        self.sourceFile = (sourceFile as NSString).lastPathComponent
        self.sourceLine = sourceLine
    }
    
    // 格式化的时间戳
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    // 格式化的日志条目（用于控制台输出）
    var formatted: String {
        return "[\(formattedTimestamp)] [\(level.rawValue)] [\(sourceFile):\(sourceLine)] \(message)"
    }
}

class AppLogger: ObservableObject {
    // 发布的日志条目数组
    @Published var logs: [LogEntry] = []
    
    // 日志文件目录
    private let logDirectory: URL
    
    // 当前日志文件
    private var currentLogFile: URL
    
    // 单例实例
    static let shared = AppLogger()
    
    // 最大日志文件大小（5MB）
    private let maxLogFileSize: UInt64 = 5 * 1024 * 1024
    
    // 保留的日志文件数量
    private let maxLogFileCount = 5
    
    private init() {
        let logsDir = AppStorageLocations.resolve().logDirectory
        
        // 创建日志目录（如果不存在）
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        logDirectory = logsDir
        
        // 创建新的日志文件
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        currentLogFile = logDirectory.appendingPathComponent("maru_\(timestamp).log")
        
        // 清理旧日志文件
        cleanupOldLogFiles()
        
        // 加载最近的日志
        loadRecentLogs()
    }
    
    // 记录日志
    func log(_ message: String, level: LogLevel, file: String = #file, line: Int = #line) {
        let entry = LogEntry(message: message, level: level, sourceFile: file, sourceLine: line)
        
        // 添加到内存日志
        DispatchQueue.main.async {
            self.logs.append(entry)
            
            // 限制内存中的日志数量
            if self.logs.count > 1000 {
                self.logs.removeFirst(self.logs.count - 1000)
            }
        }
        
        // 打印到控制台
        print(entry.formatted)
        
        // 写入日志文件
        writeToLogFile(entry)
        
        // 检查日志文件大小，如果超过限制则创建新文件
        checkLogFileSize()
    }
    
    // 清除日志
    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
    
    // 获取所有日志文件
    func getLogFiles() -> [URL] {
        let fileManager = FileManager.default
        
        do {
            // 获取日志目录中的所有文件
            let fileURLs = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil)
            
            // 过滤出.log文件并按修改日期排序
            let logFiles = fileURLs.filter { $0.pathExtension == "log" }
                .sorted(by: { lhs, rhs in
                    let lhsDate = try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate
                    let rhsDate = try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate
                    return (lhsDate ?? Date.distantPast) > (rhsDate ?? Date.distantPast)
                })
            
            return logFiles
        } catch {
            log("获取日志文件列表失败: \(error.localizedDescription)", level: .error)
            return []
        }
    }
    
    // 加载指定日志文件的内容
    func loadLogFile(_ fileURL: URL) -> [LogEntry] {
        do {
            let data = try Data(contentsOf: fileURL)
            let logContent = String(data: data, encoding: .utf8) ?? ""
            let lines = logContent.split(separator: "\n")
            
            var entries: [LogEntry] = []
            
            // 解析日志行
            for line in lines {
                if let entry = parseLogLine(String(line)) {
                    entries.append(entry)
                }
            }
            
            return entries
        } catch {
            log("加载日志文件失败: \(error.localizedDescription)", level: .error)
            return []
        }
    }
    
    // 将日志条目写入文件
    private func writeToLogFile(_ entry: LogEntry) {
        do {
            let logLine = entry.formatted + "\n"
            if let data = logLine.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: currentLogFile.path) {
                    let fileHandle = try FileHandle(forWritingTo: currentLogFile)
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                } else {
                    try data.write(to: currentLogFile, options: .atomic)
                }
            }
        } catch {
            print("写入日志文件失败: \(error.localizedDescription)")
        }
    }
    
    // 检查日志文件大小
    private func checkLogFileSize() {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: currentLogFile.path)
            let fileSize = fileAttributes[.size] as? UInt64 ?? 0
            
            if fileSize > maxLogFileSize {
                // 创建新的日志文件
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let timestamp = formatter.string(from: Date())
                currentLogFile = logDirectory.appendingPathComponent("maru_\(timestamp).log")
                
                // 清理旧日志文件
                cleanupOldLogFiles()
            }
        } catch {
            print("检查日志文件大小失败: \(error.localizedDescription)")
        }
    }
    
    // 清理旧日志文件
    private func cleanupOldLogFiles() {
        let logFiles = getLogFiles()
        
        if logFiles.count > maxLogFileCount {
            // 删除最旧的日志文件
            let filesToDelete = logFiles.suffix(from: maxLogFileCount)
            for fileURL in filesToDelete {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    // 加载最近的日志
    private func loadRecentLogs() {
        let logFiles = getLogFiles()
        
        if let mostRecentLogFile = logFiles.first {
            let entries = loadLogFile(mostRecentLogFile)
            
            // 只加载最近的100条日志
            DispatchQueue.main.async {
                self.logs = Array(entries.suffix(100))
            }
        }
    }
    
    // 解析日志行文本
    private func parseLogLine(_ line: String) -> LogEntry? {
        // 解析格式: [2023-01-01 12:34:56.789] [信息] [AppLogger.swift:123] 日志消息
        let pattern = #"\[(.*?)\] \[(.*?)\] \[(.*?):(.*?)\] (.*)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let nsString = line as NSString
        let matches = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
        
        guard let match = matches.first, match.numberOfRanges == 6 else {
            return nil
        }
        
        let timestampString = nsString.substring(with: match.range(at: 1))
        let levelString = nsString.substring(with: match.range(at: 2))
        let sourceFile = nsString.substring(with: match.range(at: 3))
        let sourceLineString = nsString.substring(with: match.range(at: 4))
        let message = nsString.substring(with: match.range(at: 5))
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        guard let _ = formatter.date(from: timestampString),
              let level = LogLevel(rawValue: levelString),
              let sourceLine = Int(sourceLineString) else {
            return nil
        }
        
        return LogEntry(message: message, level: level, sourceFile: sourceFile, sourceLine: sourceLine)
    }
}
