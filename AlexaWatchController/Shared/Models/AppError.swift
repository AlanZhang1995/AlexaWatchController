//
//  AppError.swift
//  AlexaWatchController
//
//  Core error types for the application with localized descriptions.
//

import Foundation

/// Represents application-specific errors with user-friendly descriptions.
/// Conforms to Error and LocalizedError for proper error handling and display.
public enum AppError: Error, LocalizedError, Equatable, Sendable {
    /// Network connectivity is unavailable
    case networkUnavailable
    
    /// User authentication is required (no valid token)
    case authenticationRequired
    
    /// The OAuth token has expired
    case tokenExpired
    
    /// An API error occurred with a specific message
    case apiError(String)
    
    /// The requested device was not found
    case deviceNotFound
    
    /// A device toggle operation failed with a specific reason
    case toggleFailed(String)
    
    /// A user-friendly description of the error with actionable guidance.
    /// Validates: Requirements 7.4 - Error messages should contain actionable guidance
    public var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "无法连接网络，请检查网络设置"
        case .authenticationRequired:
            return "请在 iPhone 上完成登录"
        case .tokenExpired:
            return "登录已过期，请重新登录"
        case .apiError(let message):
            return "服务错误: \(message)"
        case .deviceNotFound:
            return "设备未找到，请刷新列表"
        case .toggleFailed(let reason):
            return "操作失败: \(reason)"
        }
    }
    
    /// A short title for the error suitable for alert titles.
    public var errorTitle: String {
        switch self {
        case .networkUnavailable:
            return "网络错误"
        case .authenticationRequired:
            return "需要登录"
        case .tokenExpired:
            return "登录过期"
        case .apiError:
            return "服务错误"
        case .deviceNotFound:
            return "设备未找到"
        case .toggleFailed:
            return "操作失败"
        }
    }
    
    /// Indicates whether the error is recoverable by the user.
    public var isRecoverable: Bool {
        switch self {
        case .networkUnavailable, .toggleFailed:
            return true
        case .authenticationRequired, .tokenExpired:
            return true // Recoverable via re-authentication
        case .apiError, .deviceNotFound:
            return true // Recoverable via retry
        }
    }
    
    /// Suggested recovery action for the error.
    public var recoveryAction: String {
        switch self {
        case .networkUnavailable:
            return "请检查网络连接后重试"
        case .authenticationRequired, .tokenExpired:
            return "请在 iPhone 上重新登录"
        case .apiError, .deviceNotFound:
            return "请稍后重试"
        case .toggleFailed:
            return "请重试操作"
        }
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.networkUnavailable, .networkUnavailable):
            return true
        case (.authenticationRequired, .authenticationRequired):
            return true
        case (.tokenExpired, .tokenExpired):
            return true
        case (.apiError(let lhsMessage), .apiError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.deviceNotFound, .deviceNotFound):
            return true
        case (.toggleFailed(let lhsReason), .toggleFailed(let rhsReason)):
            return lhsReason == rhsReason
        default:
            return false
        }
    }
}
