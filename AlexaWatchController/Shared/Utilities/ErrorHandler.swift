//
//  ErrorHandler.swift
//  AlexaWatchController
//
//  Unified error handling and logging utility.
//  Validates: Requirements 7.3, 7.4
//

import Foundation
import os.log

/// Unified error handler for the application.
/// Provides centralized error logging and user-friendly error messages.
///
/// Requirements:
/// - 7.3: Log error details for debugging
/// - 7.4: Ensure error messages contain actionable guidance
final class ErrorHandler {
    
    // MARK: - Singleton
    
    static let shared = ErrorHandler()
    
    // MARK: - Properties
    
    /// Logger for error events
    private let logger = Logger(subsystem: "com.alexawatchcontroller", category: "errors")
    
    /// Error log storage for debugging
    private var errorLog: [ErrorLogEntry] = []
    private let maxLogEntries = 100
    private let logQueue = DispatchQueue(label: "com.alexawatchcontroller.errorlog")
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Handles an error by logging it and returning a user-friendly message.
    /// Validates: Requirement 7.3 - Log error details for debugging
    /// Validates: Requirement 7.4 - Error messages contain actionable guidance
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Additional context about where the error occurred
    ///   - deviceId: Optional device ID if error is device-related
    /// - Returns: A user-friendly AppError with guidance
    @discardableResult
    func handle(
        _ error: Error,
        context: ErrorContext,
        deviceId: String? = nil
    ) -> AppError {
        // Convert to AppError if needed
        let appError = convertToAppError(error)
        
        // Log the error
        // Validates: Requirement 7.3 - Log error details for debugging
        logError(appError, context: context, deviceId: deviceId, originalError: error)
        
        return appError
    }
    
    /// Logs an error without converting it.
    /// Validates: Requirement 7.3 - Log error details for debugging
    func log(
        _ error: AppError,
        context: ErrorContext,
        deviceId: String? = nil
    ) {
        logError(error, context: context, deviceId: deviceId, originalError: nil)
    }
    
    /// Gets the recent error log entries.
    func getRecentErrors(limit: Int = 20) -> [ErrorLogEntry] {
        logQueue.sync {
            Array(errorLog.suffix(limit))
        }
    }
    
    /// Clears the error log.
    func clearLog() {
        logQueue.sync {
            errorLog.removeAll()
        }
    }
    
    /// Gets guidance text for an error.
    /// Validates: Requirement 7.4 - Error messages contain actionable guidance
    func getGuidance(for error: AppError) -> String {
        switch error {
        case .networkUnavailable:
            return "请检查您的网络连接，确保 Wi-Fi 或蜂窝数据已开启"
        case .authenticationRequired:
            return "请在 iPhone 上打开 Alexa Watch Controller 应用完成登录"
        case .tokenExpired:
            return "您的登录已过期，请在 iPhone 上重新登录"
        case .apiError(let message):
            return "服务暂时不可用，请稍后重试。错误详情: \(message)"
        case .deviceNotFound:
            return "设备可能已被移除或重命名，请刷新设备列表"
        case .toggleFailed(let reason):
            return "操作失败: \(reason)。请检查设备是否在线并重试"
        }
    }
    
    // MARK: - Private Methods
    
    /// Converts a generic error to an AppError.
    private func convertToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        // Handle URLError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .apiError("请求超时")
            case .cannotFindHost, .cannotConnectToHost:
                return .apiError("无法连接到服务器")
            default:
                return .apiError(urlError.localizedDescription)
            }
        }
        
        // Handle decoding errors
        if error is DecodingError {
            return .apiError("数据解析错误")
        }
        
        // Default to API error
        return .apiError(error.localizedDescription)
    }
    
    /// Logs an error to the system log and internal log.
    /// Validates: Requirement 7.3 - Log error details for debugging
    private func logError(
        _ error: AppError,
        context: ErrorContext,
        deviceId: String?,
        originalError: Error?
    ) {
        // Create log entry
        let entry = ErrorLogEntry(
            timestamp: Date(),
            error: error,
            context: context,
            deviceId: deviceId,
            originalErrorDescription: originalError?.localizedDescription
        )
        
        // Add to internal log
        logQueue.sync {
            errorLog.append(entry)
            
            // Trim log if needed
            if errorLog.count > maxLogEntries {
                errorLog.removeFirst(errorLog.count - maxLogEntries)
            }
        }
        
        // Log to system
        let deviceInfo = deviceId.map { " [Device: \($0)]" } ?? ""
        let originalInfo = originalError.map { " Original: \($0.localizedDescription)" } ?? ""
        
        logger.error("[\(context.rawValue)]\(deviceInfo) \(error.localizedDescription)\(originalInfo)")
    }
}

// MARK: - Error Context

/// Context describing where an error occurred.
enum ErrorContext: String {
    case authentication = "Authentication"
    case deviceFetch = "DeviceFetch"
    case deviceToggle = "DeviceToggle"
    case tokenRefresh = "TokenRefresh"
    case tokenSync = "TokenSync"
    case cacheOperation = "CacheOperation"
    case complication = "Complication"
    case network = "Network"
    case unknown = "Unknown"
}

// MARK: - Error Log Entry

/// An entry in the error log.
struct ErrorLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let error: AppError
    let context: ErrorContext
    let deviceId: String?
    let originalErrorDescription: String?
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

// MARK: - Error Extensions

extension AppError {
    /// Returns the guidance text for this error.
    /// Validates: Requirement 7.4 - Error messages contain actionable guidance
    var guidance: String {
        ErrorHandler.shared.getGuidance(for: self)
    }
    
    /// Returns whether this error is recoverable by retrying.
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .apiError, .toggleFailed:
            return true
        case .authenticationRequired, .tokenExpired, .deviceNotFound:
            return false
        }
    }
    
    /// Returns the suggested action for this error.
    var suggestedAction: ErrorAction {
        switch self {
        case .networkUnavailable:
            return .retry
        case .authenticationRequired, .tokenExpired:
            return .reauthenticate
        case .apiError:
            return .retry
        case .deviceNotFound:
            return .refresh
        case .toggleFailed:
            return .retry
        }
    }
}

// MARK: - Error Action

/// Suggested action for handling an error.
enum ErrorAction {
    case retry
    case reauthenticate
    case refresh
    case dismiss
}

// MARK: - Logging Convenience

extension ErrorHandler {
    /// Logs an authentication error.
    func logAuthError(_ error: Error, deviceId: String? = nil) {
        handle(error, context: .authentication, deviceId: deviceId)
    }
    
    /// Logs a device fetch error.
    func logFetchError(_ error: Error) {
        handle(error, context: .deviceFetch)
    }
    
    /// Logs a device toggle error.
    func logToggleError(_ error: Error, deviceId: String) {
        handle(error, context: .deviceToggle, deviceId: deviceId)
    }
    
    /// Logs a token refresh error.
    func logRefreshError(_ error: Error) {
        handle(error, context: .tokenRefresh)
    }
    
    /// Logs a token sync error.
    func logSyncError(_ error: Error) {
        handle(error, context: .tokenSync)
    }
}
