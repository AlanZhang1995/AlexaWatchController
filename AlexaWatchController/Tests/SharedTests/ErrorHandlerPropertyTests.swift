//
//  ErrorHandlerPropertyTests.swift
//  AlexaWatchControllerTests
//
//  Property-based tests for error handling.
//  Tests Properties 14 and 15 from the design document.
//

import XCTest
import SwiftCheck
@testable import AlexaWatchControllerShared

/// Property-based tests for error handling.
///
/// Properties 14 & 15: Error Logging and Error Message Guidance
/// Validates: Requirements 7.3, 7.4
final class ErrorHandlerPropertyTests: XCTestCase {
    
    var errorHandler: ErrorHandler!
    
    override func setUp() {
        super.setUp()
        errorHandler = ErrorHandler.shared
        errorHandler.clearLog()
    }
    
    override func tearDown() {
        errorHandler.clearLog()
        errorHandler = nil
        super.tearDown()
    }
    
    // MARK: - Property 14: Error Logging
    
    /// **Property 14: Error Logging**
    /// *For any* error that occurs in the app, the error details should be
    /// logged for debugging purposes.
    ///
    /// **Validates: Requirements 7.3**
    func testProperty14_ErrorLogging() {
        property("Feature: alexa-watch-controller, Property 14: Error Logging") <- forAll(AppErrorGenerator.arbitrary) { (error: AppError) in
            // Clear previous logs
            self.errorHandler.clearLog()
            
            // Log the error
            self.errorHandler.log(error, context: .unknown)
            
            // Get recent errors
            let recentErrors = self.errorHandler.getRecentErrors(limit: 1)
            
            // Property: Error should be logged
            guard let logEntry = recentErrors.first else {
                return false
            }
            
            return logEntry.error == error
        }
    }
    
    /// Test that all error contexts are logged correctly.
    func testProperty14_AllContextsLogged() {
        let contexts: [ErrorContext] = [
            .authentication,
            .deviceFetch,
            .deviceToggle,
            .tokenRefresh,
            .tokenSync,
            .cacheOperation,
            .complication,
            .network,
            .unknown
        ]
        
        property("All error contexts are logged correctly") <- forAll(Gen.fromElements(of: contexts)) { (context: ErrorContext) in
            self.errorHandler.clearLog()
            
            let error = AppError.networkUnavailable
            self.errorHandler.log(error, context: context)
            
            let recentErrors = self.errorHandler.getRecentErrors(limit: 1)
            
            guard let logEntry = recentErrors.first else {
                return false
            }
            
            return logEntry.context == context
        }
    }
    
    /// Test that device ID is logged when provided.
    func testProperty14_DeviceIdLogged() {
        property("Device ID is logged when provided") <- forAll { (deviceIdSuffix: UInt16) in
            self.errorHandler.clearLog()
            
            let deviceId = "device_\(deviceIdSuffix)"
            let error = AppError.toggleFailed("Test failure")
            
            self.errorHandler.log(error, context: .deviceToggle, deviceId: deviceId)
            
            let recentErrors = self.errorHandler.getRecentErrors(limit: 1)
            
            guard let logEntry = recentErrors.first else {
                return false
            }
            
            return logEntry.deviceId == deviceId
        }
    }
    
    // MARK: - Property 15: Error Message Guidance
    
    /// **Property 15: Error Message Guidance**
    /// *For any* error displayed to the user, the error message should contain
    /// actionable guidance (e.g., "请检查网络设置" or "请重新登录").
    ///
    /// **Validates: Requirements 7.4**
    func testProperty15_ErrorMessageGuidance() {
        property("Feature: alexa-watch-controller, Property 15: Error Message Guidance") <- forAll(AppErrorGenerator.arbitrary) { (error: AppError) in
            let guidance = self.errorHandler.getGuidance(for: error)
            
            // Property: Guidance should not be empty
            guard !guidance.isEmpty else {
                return false
            }
            
            // Property: Guidance should contain actionable text
            // Check for common action words in Chinese
            let actionWords = ["请", "检查", "重新", "刷新", "重试", "确保", "打开"]
            let containsActionWord = actionWords.contains { guidance.contains($0) }
            
            return containsActionWord
        }
    }
    
    /// Test that all error types have guidance.
    func testProperty15_AllErrorsHaveGuidance() {
        let allErrors: [AppError] = [
            .networkUnavailable,
            .authenticationRequired,
            .tokenExpired,
            .apiError("Test error"),
            .deviceNotFound,
            .toggleFailed("Test failure")
        ]
        
        for error in allErrors {
            let guidance = errorHandler.getGuidance(for: error)
            XCTAssertFalse(guidance.isEmpty, "Error \(error) should have guidance")
        }
    }
    
    /// Test that error descriptions are user-friendly.
    func testProperty15_UserFriendlyDescriptions() {
        property("Error descriptions are user-friendly") <- forAll(AppErrorGenerator.arbitrary) { (error: AppError) in
            let description = error.localizedDescription
            
            // Property: Description should not be empty
            guard !description.isEmpty else {
                return false
            }
            
            // Property: Description should be in Chinese (contains Chinese characters)
            let chineseRange = description.range(of: "\\p{Han}", options: .regularExpression)
            
            return chineseRange != nil
        }
    }
}

// MARK: - AppError Generator

/// Generator for AppError values for property testing.
struct AppErrorGenerator {
    static var arbitrary: Gen<AppError> {
        return Gen<AppError>.fromElements(of: [
            .networkUnavailable,
            .authenticationRequired,
            .tokenExpired,
            .apiError("测试错误"),
            .apiError("服务器错误 500"),
            .apiError("请求超时"),
            .deviceNotFound,
            .toggleFailed("设备无响应"),
            .toggleFailed("网络错误"),
            .toggleFailed("权限不足")
        ])
    }
}

// MARK: - Arbitrary Conformance

extension AppError: Arbitrary {
    public static var arbitrary: Gen<AppError> {
        return AppErrorGenerator.arbitrary
    }
}

extension ErrorContext: Arbitrary {
    public static var arbitrary: Gen<ErrorContext> {
        return Gen<ErrorContext>.fromElements(of: [
            .authentication,
            .deviceFetch,
            .deviceToggle,
            .tokenRefresh,
            .tokenSync,
            .cacheOperation,
            .complication,
            .network,
            .unknown
        ])
    }
}

// MARK: - Unit Tests

final class ErrorHandlerTests: XCTestCase {
    
    var errorHandler: ErrorHandler!
    
    override func setUp() {
        super.setUp()
        errorHandler = ErrorHandler.shared
        errorHandler.clearLog()
    }
    
    override func tearDown() {
        errorHandler.clearLog()
        errorHandler = nil
        super.tearDown()
    }
    
    // MARK: - Logging Tests
    
    func testErrorHandler_LogsError() {
        let error = AppError.networkUnavailable
        errorHandler.log(error, context: .network)
        
        let recentErrors = errorHandler.getRecentErrors(limit: 1)
        
        XCTAssertEqual(recentErrors.count, 1)
        XCTAssertEqual(recentErrors.first?.error, error)
        XCTAssertEqual(recentErrors.first?.context, .network)
    }
    
    func testErrorHandler_LogsMultipleErrors() {
        errorHandler.log(.networkUnavailable, context: .network)
        errorHandler.log(.authenticationRequired, context: .authentication)
        errorHandler.log(.deviceNotFound, context: .deviceFetch)
        
        let recentErrors = errorHandler.getRecentErrors(limit: 10)
        
        XCTAssertEqual(recentErrors.count, 3)
    }
    
    func testErrorHandler_ClearsLog() {
        errorHandler.log(.networkUnavailable, context: .network)
        errorHandler.log(.authenticationRequired, context: .authentication)
        
        errorHandler.clearLog()
        
        let recentErrors = errorHandler.getRecentErrors()
        XCTAssertTrue(recentErrors.isEmpty)
    }
    
    func testErrorHandler_LimitsLogSize() {
        // Log more than max entries
        for i in 0..<150 {
            errorHandler.log(.apiError("Error \(i)"), context: .unknown)
        }
        
        let recentErrors = errorHandler.getRecentErrors(limit: 200)
        
        // Should be limited to maxLogEntries (100)
        XCTAssertLessThanOrEqual(recentErrors.count, 100)
    }
    
    // MARK: - Guidance Tests
    
    func testErrorHandler_NetworkUnavailableGuidance() {
        let guidance = errorHandler.getGuidance(for: .networkUnavailable)
        
        XCTAssertTrue(guidance.contains("网络"))
        XCTAssertTrue(guidance.contains("检查"))
    }
    
    func testErrorHandler_AuthRequiredGuidance() {
        let guidance = errorHandler.getGuidance(for: .authenticationRequired)
        
        XCTAssertTrue(guidance.contains("iPhone"))
        XCTAssertTrue(guidance.contains("登录"))
    }
    
    func testErrorHandler_TokenExpiredGuidance() {
        let guidance = errorHandler.getGuidance(for: .tokenExpired)
        
        XCTAssertTrue(guidance.contains("过期"))
        XCTAssertTrue(guidance.contains("重新登录"))
    }
    
    // MARK: - Error Conversion Tests
    
    func testErrorHandler_HandlesURLError() {
        let urlError = URLError(.notConnectedToInternet)
        let appError = errorHandler.handle(urlError, context: .network)
        
        XCTAssertEqual(appError, .networkUnavailable)
    }
    
    func testErrorHandler_HandlesTimeoutError() {
        let urlError = URLError(.timedOut)
        let appError = errorHandler.handle(urlError, context: .network)
        
        if case .apiError(let message) = appError {
            XCTAssertTrue(message.contains("超时"))
        } else {
            XCTFail("Expected apiError with timeout message")
        }
    }
    
    // MARK: - Error Extension Tests
    
    func testAppError_IsRetryable() {
        XCTAssertTrue(AppError.networkUnavailable.isRetryable)
        XCTAssertTrue(AppError.apiError("test").isRetryable)
        XCTAssertTrue(AppError.toggleFailed("test").isRetryable)
        
        XCTAssertFalse(AppError.authenticationRequired.isRetryable)
        XCTAssertFalse(AppError.tokenExpired.isRetryable)
        XCTAssertFalse(AppError.deviceNotFound.isRetryable)
    }
    
    func testAppError_SuggestedAction() {
        XCTAssertEqual(AppError.networkUnavailable.suggestedAction, .retry)
        XCTAssertEqual(AppError.authenticationRequired.suggestedAction, .reauthenticate)
        XCTAssertEqual(AppError.tokenExpired.suggestedAction, .reauthenticate)
        XCTAssertEqual(AppError.deviceNotFound.suggestedAction, .refresh)
        XCTAssertEqual(AppError.toggleFailed("test").suggestedAction, .retry)
    }
}
