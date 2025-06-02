// The Swift Programming Language
// https://docs.swift.org/swift-book

// MARK: - Global Logging Function (Modified)
/// - Parameters:
///   - manager: Optional LogManager instance. If `nil` (default), `LogManager.shared` is used.
///   - group: Log group name.
///   - type: Log type.
///   - message: Log messages.
///   - file: (AutoFill) The source file name that calls this function.
///   - function: (AutoFill) The function name that calls this function.
///   - line: (AutoFill) The line number of this function in the source file is called.
public func AppLog(
    using manager: LogManager? = nil,
    group: String,
    type: ServerLogType,
    message: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    let loggerInstance = manager ?? LogManager.shared
    Task {
        await loggerInstance.log(group: group, type: type, message: message, file: file, function: function, line: line)
    }
}
