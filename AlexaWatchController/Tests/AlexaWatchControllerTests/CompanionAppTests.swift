//
//  CompanionAppTests.swift
//  AlexaWatchControllerTests
//
//  Unit tests for iOS Companion App components.
//  Validates: Requirements 1.2, 1.6
//

import XCTest
@testable import AlexaWatchControllerShared

/// Unit tests for iOS Companion App components.
///
/// Requirements:
/// - 1.2: Handle OAuth callback
/// - 1.6: Display error on authentication failure
final class CompanionAppTests: XCTestCase {
    
    // MARK: - OAuth Callback Tests
    
    /// Test OAuth callback handling with valid authorization code.
    /// Validates: Requirement 1.2 - Handle OAuth callback
    @MainActor
    func testOAuthCallback_ValidCode() async {
        let authService = MockAuthServiceForCompanion()
        let connectivityService = MockConnectivityServiceForCompanion()
        
        let viewModel = AuthViewModel(
            authService: authService,
            connectivityService: connectivityService
        )
        
        // Simulate OAuth callback with valid code
        let callbackURL = URL(string: "alexawatchcontroller://oauth/callback?code=valid_auth_code")!
        
        await viewModel.handleOAuthCallback(url: callbackURL)
        
        XCTAssertTrue(viewModel.isAuthenticated, "Should be authenticated after valid callback")
        XCTAssertNil(viewModel.error, "Should have no error after valid callback")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after callback completes")
    }
    
    /// Test OAuth callback handling with invalid/missing code.
    /// Validates: Requirement 1.6 - Display error on authentication failure
    @MainActor
    func testOAuthCallback_InvalidCode() async {
        let authService = MockAuthServiceForCompanion()
        authService.shouldFailCallback = true
        
        let connectivityService = MockConnectivityServiceForCompanion()
        
        let viewModel = AuthViewModel(
            authService: authService,
            connectivityService: connectivityService
        )
        
        // Simulate OAuth callback with invalid code
        let callbackURL = URL(string: "alexawatchcontroller://oauth/callback?error=access_denied")!
        
        await viewModel.handleOAuthCallback(url: callbackURL)
        
        XCTAssertFalse(viewModel.isAuthenticated, "Should not be authenticated after failed callback")
        XCTAssertNotNil(viewModel.error, "Should have error after failed callback")
    }
    
    /// Test OAuth callback syncs token to Watch.
    /// Validates: Requirement 1.4 - Sync token to Watch
    @MainActor
    func testOAuthCallback_SyncsTokenToWatch() async {
        let authService = MockAuthServiceForCompanion()
        let connectivityService = MockConnectivityServiceForCompanion()
        
        let viewModel = AuthViewModel(
            authService: authService,
            connectivityService: connectivityService
        )
        
        let callbackURL = URL(string: "alexawatchcontroller://oauth/callback?code=valid_auth_code")!
        
        await viewModel.handleOAuthCallback(url: callbackURL)
        
        // On iOS, token should be synced to Watch
        #if os(iOS)
        XCTAssertNotNil(connectivityService.sentToken, "Token should be synced to Watch after successful auth")
        #endif
    }
    
    // MARK: - Authentication Failure Tests
    
    /// Test authentication failure displays error.
    /// Validates: Requirement 1.6 - Display error message on auth failure
    @MainActor
    func testAuthFailure_DisplaysError() async {
        let authService = MockAuthServiceForCompanion()
        authService.shouldFailOAuth = true
        authService.oauthError = .networkUnavailable
        
        let connectivityService = MockConnectivityServiceForCompanion()
        
        let viewModel = AuthViewModel(
            authService: authService,
            connectivityService: connectivityService
        )
        
        await viewModel.login()
        
        XCTAssertFalse(viewModel.isAuthenticated, "Should not be authenticated after failure")
        XCTAssertNotNil(viewModel.error, "Should display error after failure")
        XCTAssertEqual(viewModel.error, .networkUnavailable, "Should show correct error type")
    }
    
    /// Test authentication failure allows retry.
    /// Validates: Requirement 1.6 - Allow retry on auth failure
    @MainActor
    func testAuthFailure_AllowsRetry() async {
        let authService = MockAuthServiceForCompanion()
        authService.shouldFailOAuth = true
        
        let connectivityService = MockConnectivityServiceForCompanion()
        
        let viewModel = AuthViewModel(
            authService: authService,
            connectivityService: connectivityService
        )
        
        // First attempt fails
        await viewModel.login()
        XCTAssertNotNil(viewModel.error)
        
        // Clear error and retry
        viewModel.clearError()
        XCTAssertNil(viewModel.error, "Error should be cleared")
        
        // Second attempt succeeds
        authService.shouldFailOAuth = false
        await viewModel.login()
        
        // Note: On iOS, login() initiates OAuth flow but doesn't complete it
        // The actual authentication happens in handleOAuthCallback
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after initiating OAuth")
    }
    
    // MARK: - Logout Tests
    
    /// Test logout clears authentication state.
    @MainActor
    func testLogout_ClearsAuthState() async {
        let authService = MockAuthServiceForCompanion()
        let connectivityService = MockConnectivityServiceForCompanion()
        
        let viewModel = AuthViewModel(
            authService: authService,
            connectivityService: connectivityService
        )
        
        // First authenticate
        let callbackURL = URL(string: "alexawatchcontroller://oauth/callback?code=valid")!
        await viewModel.handleOAuthCallback(url: callbackURL)
        XCTAssertTrue(viewModel.isAuthenticated)
        
        // Then logout
        viewModel.logout()
        
        XCTAssertFalse(viewModel.isAuthenticated, "Should not be authenticated after logout")
        XCTAssertNil(viewModel.error, "Should have no error after logout")
    }
    
    // MARK: - Token Refresh Tests
    
    /// Test token refresh on expiring token.
    @MainActor
    func testTokenRefresh_OnExpiringToken() async {
        let authService = MockAuthServiceForCompanion()
        // Set token that needs refresh (expires in 4 minutes)
        authService.storedToken = AuthToken(
            accessToken: "expiring_token",
            refreshToken: "refresh_token",
            expiresAt: Date().addingTimeInterval(240), // 4 minutes
            tokenType: "Bearer"
        )
        
        let connectivityService = MockConnectivityServiceForCompanion()
        
        let viewModel = AuthViewModel(
            authService: authService,
            connectivityService: connectivityService
        )
        
        viewModel.checkAuthStatus()
        
        // Token needs refresh but is still valid
        XCTAssertTrue(viewModel.isAuthenticated, "Should still be authenticated with expiring token")
    }
}

// MARK: - Mock Services

class MockAuthServiceForCompanion: AuthServiceProtocol {
    var storedToken: AuthToken?
    var shouldFailOAuth: Bool = false
    var shouldFailCallback: Bool = false
    var shouldFailRefresh: Bool = false
    var oauthError: AppError = .networkUnavailable
    
    func initiateOAuth() async throws {
        if shouldFailOAuth {
            throw oauthError
        }
        // OAuth initiated - waiting for callback
    }
    
    func handleCallback(url: URL) async throws -> AuthToken {
        if shouldFailCallback {
            throw AppError.authenticationRequired
        }
        
        let token = AuthToken(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
        storedToken = token
        return token
    }
    
    func refreshToken() async throws -> AuthToken {
        if shouldFailRefresh {
            throw AppError.tokenExpired
        }
        
        let token = AuthToken(
            accessToken: "refreshed_access_token",
            refreshToken: "refreshed_refresh_token",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
        storedToken = token
        return token
    }
    
    func getStoredToken() -> AuthToken? {
        return storedToken
    }
    
    func clearToken() {
        storedToken = nil
    }
}

class MockConnectivityServiceForCompanion: ConnectivityServiceProtocol {
    var sentToken: AuthToken?
    var receivedToken: AuthToken?
    var isReachable: Bool = true
    
    func sendToken(_ token: AuthToken) {
        sentToken = token
    }
    
    func receiveToken() -> AuthToken? {
        return receivedToken
    }
    
    func requestToken() {
        // No-op
    }
    
    func clearReceivedToken() {
        receivedToken = nil
    }
}
