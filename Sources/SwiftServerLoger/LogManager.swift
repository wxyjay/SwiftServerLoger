//
//  LogManager.swift
//  SwiftServerLoger
//
//  Created by Zain Wu on 2025/6/3.
//

import Foundation
#if canImport(System)
import System
#endif

public actor LogManager {
    public static let shared = LogManager()

    private var config: LogManagerConfig
    private var logDirectoryURL: URL

    private let fileManager = FileManager.default
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    private init() {
        self.config = LogManagerConfig.default
        self.logDirectoryURL = URL(fileURLWithPath: self.config.logDirectoryPath, isDirectory: true)

        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = [.sortedKeys]
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
        
        // Ensure that the default log directory exists at the beginning (based on the default configuration)
        Task { [weak self] in
            await self?.ensureLogDirectoryExistsSync()
        }
    }
    
    /// Use the configuration you provide yourself.
    /// - Parameter config: A specific configuration for this LogManager instance.
    public init(config: LogManagerConfig) {
        self.config = config
        self.logDirectoryURL = URL(fileURLWithPath: self.config.logDirectoryPath, isDirectory: true)

        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = [.sortedKeys]
        self.jsonEncoder.dateEncodingStrategy = .iso8601

        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .iso8601
        
        Task { [weak self] in
            await self?.ensureLogDirectoryExistsSync()
        }
        #if DEBUG
        print("Custom LogManager instance created. Log directory: \(config.logDirectoryPath)")
        #endif
    }

    private func ensureLogDirectoryExistsSync() {
        do {
            if !fileManager.fileExists(atPath: logDirectoryURL.path) {
                try fileManager.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                #if DEBUG
                print("Log directory created/ensured at: \(logDirectoryURL.path)")
                #endif
            }
        } catch {
            print("Error creating log directory \(logDirectoryURL.path): \(error). Logging may fail.")
        }
    }

    /// Configure LogManager.
    /// - Parameter newConfig: Log configuration to apply.
    public func configure(with newConfig: LogManagerConfig) {
        self.config = newConfig
        
        let newLogDirectoryURL = URL(fileURLWithPath: newConfig.logDirectoryPath, isDirectory: true)
        if newLogDirectoryURL != self.logDirectoryURL {
            self.logDirectoryURL = newLogDirectoryURL
            // Make sure the new directory exists
            ensureLogDirectoryExistsSync()
            #if DEBUG
            print("Log directory path updated to: \(self.logDirectoryURL.path)")
            #endif
        }
        #if DEBUG
        print("LogManager configured with path: \(self.config.logDirectoryPath), default max entries: \(self.config.defaultMaxEntriesPerGroup)")
        #endif
    }

    public func getCurrentConfig() -> LogManagerConfig {
        return self.config
    }

    // MARK: - Logging
    public func log(group: String, type: ServerLogType, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        
        let enrichedMessage = "[\(URL(fileURLWithPath: file).lastPathComponent):\(line) \(function)] \(message)"
        let entry = ServerLogEntry(group: group, type: type, message: enrichedMessage)
        
        #if DEBUG
        let debugPrefix = "[\(entry.timestamp)] [\(group)] [\(type.rawValue.uppercased())]"
        print("\(debugPrefix): \(enrichedMessage)")
        #endif
        
        let sanitizedGroupName = sanitizeFileName(group)
        let groupLogDirectoryURL = self.logDirectoryURL.appendingPathComponent(sanitizedGroupName, isDirectory: true)
        let logFileURL = groupLogDirectoryURL.appendingPathComponent("logs.jsonl") // 使用 .jsonl 表示 JSON Lines

        do {
            if !self.fileManager.fileExists(atPath: groupLogDirectoryURL.path) {
                try self.fileManager.createDirectory(at: groupLogDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            }

            var logsInGroup: [ServerLogEntry] = []
            if self.fileManager.fileExists(atPath: logFileURL.path) {
                if let data = try? Data(contentsOf: logFileURL) {
                    let lines = String(data: data, encoding: .utf8)?.split(separator: "\n", omittingEmptySubsequences: true) ?? []
                    logsInGroup = lines.compactMap { line in
                        try? self.jsonDecoder.decode(ServerLogEntry.self, from: Data(line.utf8))
                    }
                }
            }

            logsInGroup.append(entry)
            logsInGroup.sort { $0.timestamp < $1.timestamp }

            let maxEntries = self.config.groupSpecificMaxEntries[group] ?? self.config.defaultMaxEntriesPerGroup
            if logsInGroup.count > maxEntries && maxEntries > 0 { // maxEntries > 0 避免移除所有条目
                logsInGroup.removeFirst(logsInGroup.count - maxEntries)
            }

            // Recoded to JSON Lines format
            let linesToWrite = try logsInGroup.map { logEntry -> String in
                let entryData = try self.jsonEncoder.encode(logEntry)
                return String(data: entryData, encoding: .utf8) ?? ""
            }.filter { !$0.isEmpty }
            
            // Each entry takes up one line, separated by newline characters
            let fileContent = linesToWrite.joined(separator: "\n") + (linesToWrite.isEmpty ? "" : "\n") // 确保最后有一个换行符
            try fileContent.data(using: .utf8)?.write(to: logFileURL, options: .atomic)

        } catch {
            #if DEBUG
            print("Error writing log to file for group \(group) at \(logFileURL.path): \(error)")
            #endif
        }
    }
    
    private func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\":<> ").union(.whitespacesAndNewlines)
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
    }

    // MARK: - Log Reading
    public func getAllLogGroups() -> [LogGroupInfo] {
        var groups: [LogGroupInfo] = []
        guard fileManager.fileExists(atPath: logDirectoryURL.path) else {
            #if DEBUG
            print("Log directory not found at \(logDirectoryURL.path) when trying to get all log groups.")
            #endif
            return []
        }
        
        do {
            let items = try fileManager.contentsOfDirectory(at: logDirectoryURL, includingPropertiesForKeys: [.isDirectoryKey, .nameKey, .contentModificationDateKey], options: .skipsHiddenFiles)
            for itemURL in items {
                var isDir: ObjCBool = false
                let groupName = itemURL.lastPathComponent 
                
                if fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir), isDir.boolValue {
                    let logFileURL = itemURL.appendingPathComponent("logs.jsonl")
                    var entryCount = 0
                    var lastLogDate: Date? = nil

                    if fileManager.fileExists(atPath: logFileURL.path) {
                        if let data = try? Data(contentsOf: logFileURL) {
                            let lines = String(data: data, encoding: .utf8)?.split(separator: "\n", omittingEmptySubsequences: true) ?? []
                            entryCount = lines.count
                            if let lastLine = lines.last, let lastEntryData = lastLine.data(using: .utf8) {
                                if let lastLog = try? jsonDecoder.decode(ServerLogEntry.self, from: lastEntryData) {
                                    lastLogDate = lastLog.timestamp
                                }
                            }
                        }
                    }
                    groups.append(LogGroupInfo(name: groupName, entryCount: entryCount, lastLogDate: lastLogDate))
                }
            }
            groups.sort { ($0.lastLogDate ?? .distantPast) > ($1.lastLogDate ?? .distantPast) }
        } catch {
            #if DEBUG
            print("Error reading log groups from \(logDirectoryURL.path): \(error)")
            #endif
        }
        return groups
    }

    public func getLogs(group: String, startDate: Date? = nil, endDate: Date? = nil, limit: Int = 100, ascending: Bool = false) -> [ServerLogEntry] {
        let sanitizedGroupName = sanitizeFileName(group)
        let groupLogDirectoryURL = self.logDirectoryURL.appendingPathComponent(sanitizedGroupName, isDirectory: true)
        let logFileURL = groupLogDirectoryURL.appendingPathComponent("logs.jsonl")
        
        guard fileManager.fileExists(atPath: logFileURL.path) else {
            #if DEBUG
            print("Log file for group \(group) (sanitized: \(sanitizedGroupName)) not found at \(logFileURL.path)")
            #endif
            return []
        }

        do {
            let data = try Data(contentsOf: logFileURL)
            let lines = String(data: data, encoding: .utf8)?.split(separator: "\n", omittingEmptySubsequences: true) ?? []
            var logs: [ServerLogEntry] = lines.compactMap { line in
                return try? self.jsonDecoder.decode(ServerLogEntry.self, from: Data(line.utf8))
            }
            
            // The log file itself has been stored in ascending order in time
            // filter
            if let startDate = startDate {
                logs.removeAll { $0.timestamp < startDate }
            }
            if let endDate = endDate {
                // Adjust endDate to the start of the next day so that it can be compared with < to include all logs of endDate for the day
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: endDate)
                components.hour = 0
                components.minute = 0
                components.second = 0
                if let adjustedEndDateStartOfDay = calendar.date(from: components),
                   let effectiveEndDate = calendar.date(byAdding: .day, value: 1, to: adjustedEndDateStartOfDay) {
                    logs.removeAll { $0.timestamp >= effectiveEndDate }
                } else {
                    // If the date adjustment fails, use the original endDate for > comparison (may not exactly as expected)
                    logs.removeAll { $0.timestamp > endDate }
                }
            }

            // Sort
            if !ascending { // If descending order is required (the latest one is first)
                logs.reverse() // Because the file is already in ascending order, you can directly reverse it to get descending order
            }
            
            // Limit number (applied after sorting)
            if logs.count > limit && limit >= 0 { // limit >= 0 Ensure no errors occur due to negative limits
                logs = Array(logs.prefix(limit))
            }
            return logs

        } catch {
            #if DEBUG
            print("Error reading logs for group \(group) from \(logFileURL.path): \(error)")
            #endif
            return []
        }
    }
}

