//
//  LogModels.swift
//  SwiftServerLoger
//
//  Created by Zain Wu on 2025/6/3.
//


import Foundation

// MARK: - Public Enums and Structs for Logging

/// Log Type
public enum ServerLogType: String, Codable, CaseIterable, Sendable {
    case debug
    case info
    case warning
    case error
    case critical
    case audit // Example: Audit log
}

/// Single log entry
public struct ServerLogEntry: Codable, Identifiable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var group: String
    public var type: ServerLogType
    public var message: String
    // `Sendable` Make sure it can be used in a concurrent environment

    public init(id: UUID = UUID(), timestamp: Date = Date(), group: String, type: ServerLogType, message: String) {
        self.id = id
        self.timestamp = timestamp
        self.group = group
        self.type = type
        self.message = message
    }
}

/// LogManager Configuration
public struct LogManagerConfig: Codable, Sendable {
    public var logDirectoryPath: String
    public var defaultMaxEntriesPerGroup: Int
    public var groupSpecificMaxEntries: [String: Int] // Key: groupName, Value: maxEntries

    public static let `default` = LogManagerConfig(
        logDirectoryPath: "./server_logs", // Default log directory, relative to executable files
        defaultMaxEntriesPerGroup: 1000,
        groupSpecificMaxEntries: [:]
    )
}

/// Log group information
public struct LogGroupInfo: Codable, Identifiable, Sendable {
    public var id: String { name } // Group name as unique identifier
    public let name: String
    public var entryCount: Int
    public var lastLogDate: Date?

    public init(name: String, entryCount: Int, lastLogDate: Date? = nil) {
        self.name = name
        self.entryCount = entryCount
        self.lastLogDate = lastLogDate
    }
}

