# SwiftServerLoger 🪵

[![Swift 6.1](https://img.shields.io/badge/Swift-6.1-orange.svg)](https://swift.org)
[![macOS 10.15+](https://img.shields.io/badge/macOS-10.15%2B-blue.svg)](https://www.apple.com/macos)
[![Linux](https://img.shields.io/badge/Linux-Supported-yellow.svg)](https://www.linux.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/wxyjay/SwiftServerLoger/blob/main/LICENSE)

SwiftServerLoger is a powerful, thread-safe logging library for server-side Swift applications running on macOS or Linux. It's designed for ease of use, flexibility, and performance, utilizing Swift Actors for concurrency safety.

## Features ✨

* **Thread-Safe**: Built with Swift Actors to ensure safe concurrent access.
* **File-Based Logging**: Writes logs to files in JSON Lines (`.jsonl`) format.
* **Configurable**:

  * Customize log directory path.
  * Set default maximum log entries per group.
  * Define specific maximum entries for individual log groups.
* **Group-Based Logging**: Organize logs into different groups (e.g., "database", "network", "user\_activity").
* **Multiple Instances**: Supports `LogManager.shared` singleton and creation of multiple `LogManager` instances with distinct configurations.
* **Easy Global Access**: Provides a simple `AppLog()` global function for quick logging.
* **Contextual Information**: Automatically includes timestamp, log type, group, message, source file, function, and line number.
* **Log Reading**: Utility functions to retrieve log group information and read log entries with filtering options.

## Requirements 📋

* Swift 6.0 or later (Developed with Swift 6.1)
* macOS 10.15 or later
* Linux (Tested on Ubuntu, should work on most distributions with Swift installed)

## Installation 📦

Add `SwiftServerLoger` as a dependency to your `Package.swift` file:

```swift
// In your Package.swift
dependencies: [
    .package(url: "https://github.com/wxyjay/SwiftServerLoger.git", from: "1.0.0")
]

// And add it to your target's dependencies:
.target(
    name: "YourAppTarget",
    dependencies: [
        .product(name: "SwiftServerLoger", package: "SwiftServerLoger") 
    ]
)
```

## Basic Usage 🚀

### 1. Import the Library

```swift
import SwiftServerLogger
```

### 2. Configure the Shared Logger (Optional, but Recommended)

It's best to configure the logger early in your application's lifecycle, for example, in your `main.swift` or application setup:

```swift
func setupSharedLogger() {
    let logDirectory: String
    #if os(Linux)
    logDirectory = "/var/log/YourAppName" // Ensure this directory is writable
    #else
    if let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
        logDirectory = appSupportDir.appendingPathComponent("YourAppName/Logs").path
        try? FileManager.default.createDirectory(atPath: logDirectory, withIntermediateDirectories: true, attributes: nil)
    } else {
        logDirectory = "./YourAppLogs" // Fallback
    }
    #endif

    let sharedConfig = LogManagerConfig(
        logDirectoryPath: logDirectory,
        defaultMaxEntriesPerGroup: 2000,
        groupSpecificMaxEntries: ["critical_service": 5000]
    )

    Task {
        await LogManager.shared.configure(with: sharedConfig)
        print("✅ Shared logger configured. Log directory: \(logDirectory)")
        AppLog(group: "system_setup", type: .info, message: "Shared logger initialized and configured.")
    }
}

// Call this setup function early
setupSharedLogger()
```

### 3. Log Messages

Use the global `AppLog` function to log messages. It defaults to using `LogManager.shared`.

```swift
AppLog(group: "user_auth", type: .info, message: "User 'john_doe' logged in successfully.")
AppLog(group: "database_query", type: .debug, message: "Fetched 10 records from 'products' table.")

func processOrder(orderId: String) {
    AppLog(group: "orders", type: .info, message: "Processing order \(orderId)...")
    if let error = simulateError() {
        AppLog(group: "orders", type: .error, message: "Failed to process order \(orderId): \(error.localizedDescription)")
    } else {
        AppLog(group: "orders", type: .audit, message: "Order \(orderId) processed successfully.")
    }
}

func simulateError() -> Error? {
    struct MyError: LocalizedError { var errorDescription: String? = "Simulated processing error" }
    return Bool.random() ? MyError() : nil
}

processOrder(orderId: "ORD12345")
```

## Advanced Usage 🛠️

### Creating and Using Custom `LogManager` Instances

You can create multiple `LogManager` instances, each with its own configuration:

```swift
let paymentLogsConfig = LogManagerConfig(
    logDirectoryPath: "./payment_module_logs",
    defaultMaxEntriesPerGroup: 1000,
    groupSpecificMaxEntries: ["transactions": 5000, "fraud_alerts": 10000]
)

let paymentLogger = LogManager(config: paymentLogsConfig)

AppLog(using: paymentLogger, group: "transactions", type: .info, message: "Payment received: $99.99 for order #TRX789.")
AppLog(using: paymentLogger, group: "fraud_alerts", type: .warning, message: "Suspicious activity detected for user 'jane_doe'.")

AppLog(group: "general_app", type: .info, message: "General application health check OK.")
```

### Reading Logs

```swift
Task {
    let logGroupsInfo = await LogManager.shared.getAllLogGroups()
    for groupInfo in logGroupsInfo {
        print("Group: \(groupInfo.name), Entries: \(groupInfo.entryCount), Last Log: \(groupInfo.lastLogDate ?? Date.distantPast)")
    }

    let orderErrors = await LogManager.shared.getLogs(
        group: "orders",
        limit: 5,
        ascending: false
    ).filter { $0.type == .error }

    for entry in orderErrors {
        print("Order Error: [\(entry.timestamp)] \(entry.message)")
    }

    let transactionLogs = await paymentLogger.getLogs(group: "transactions", limit: 10)
    print("\nRecent Payment Transactions:")
    for entry in transactionLogs {
        print("[\(entry.timestamp)] \(entry.message)")
    }
}
```

> **Note**: Make sure `paymentLogger` is accessible in the scope where you try to read logs from it.

## Configuration Options ⚙️

The `LogManagerConfig` struct allows you to specify:

* `logDirectoryPath: String`: The path to the directory where log group folders are created.
* `defaultMaxEntriesPerGroup: Int`: Default maximum log entries per group.
* `groupSpecificMaxEntries: [String: Int]`: Custom max entries for specific groups.

## License 📄

SwiftServerLoger is released under the MIT License. See the [LICENSE](https://github.com/wxyjay/SwiftServerLoger/blob/main/LICENSE) file for details.

**Happy Logging!**
