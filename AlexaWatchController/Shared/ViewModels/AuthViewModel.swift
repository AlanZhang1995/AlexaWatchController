//
//  AuthViewModel.swift
//  AlexaWatchController
//
//  ViewModel for managing authentication state and operations.
//  Validates: Requirements 1.1, 1.5, 1.6, 7.2
//

import Foundation
import Combine

/// ViewModel responsible for managing authentication state and operations.
/// Handles login, logout, token validation, and token refresh logic.
///
/// Requirements:
/// - 1.1: Prompt user to complete authentication via Companion App
/// - 1.5: Notify user to re-authenticate if token expires
/// - 1.6: Display error message and allow retry on auth failure
/// - 7.2: Redirect to re-authentication if token is invalid
@MainActor
class AuthViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Indicates whether the user is currently authenticated with a valid token.
    @Published private(set) var isAuthenticated: Bool = false
    
    /// Indicates whether an authentication operation is in progress.
    @Published private(set) var isLoading: Bool = false
    
    /// The current error, if any. Nil when there's no error.
    /// Validates: Requirement 1.6 - Display error message on auth failure
    @Published var error: AppError?
    
    /// Indicates whether the user needs to authenticate on the companion app.
    /// Validates: Requirement 1.1 - Prompt user to complete authentication via Companion App
    @Published private(set) var needsCompanionAuth: Bool = false
    
    // MARK: - Dependencies
    
    /// The authentication service for OAuth operations
    private let authService: AuthServiceProtocol
    
    /// The connectivity service for token synchronization
    private let connectivityService: ConnectivityServiceProtocol
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Timer for periodic token refresh checks
    private var tokenRefreshTimer: Timer?
    
    // MARK: - Initialization
    
    /// Creates a new AuthViewModel instance.
    /// - Parameters:
    ///   - authService: The authentication service to use
    ///   - connectivityService: The connectivity service for token sync
    init(
        authService: AuthServiceProtocol,
        connectivityService: ConnectivityServiceProtocol
    ) {
        self.authService = authService
        self.connectivityService = connectivityService
        
        // Check initial auth status
        checkAuthStatus()
        
        // Set up token refresh monitoring
        setupTokenRefreshMonitoring()
    }
    
    /// Convenience initializer using default services.
    convenience init() {
        self.init(
            authService: AuthService(),
            connectivityService: ConnectivityService.shared
        )
    }
    
    deinit {
        tokenRefreshTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Initiates the login process.
    /// On iOS: Opens the OAuth authorization page.
    /// On watchOS: Prompts user to authenticate via Companion App.
    ///
    /// Validates: Requirement 1.1 - Prompt user to complete authentication via Companion App
    /// Validates: Requirement 1.6 - Allow retry on auth failure
    func login() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        #if os(watchOS)
        // On watchOS, request token from iOS Companion App
        // Validates: Requirement 1.1 - Prompt user to complete authentication via Companion App
        connectivityService.requestToken()
        needsCompanionAuth = true
        isLoading = false
        
        // Check if token was received after a short delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        checkForReceivedToken()
        #else
        // On iOS, initiate OAuth flow
        do {
            try await authService.initiateOAuth()
            // OAuth flow initiated - waiting for callback
            // isLoading will be set to false when callback is handled
        } catch let appError as AppError {
            // Validates: Requirement 1.6 - Display error message on auth failure
            self.error = appError
            isLoading = false
        } catch {
            self.error = .networkUnavailable
            isLoading = false
        }
        #endif
    }
    
    /// Logs out the current user by clearing stored tokens.
    func logout() {
        authService.clearToken()
        connectivityService.clearReceivedToken()
        
        isAuthenticated = false
        needsCompanionAuth = false
        error = nil
        
        // Stop token refresh monitoring
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
    }
    
    /// Checks the current authentication status.
    /// Updates `isAuthenticated` based on token validity.
    ///
    /// Validates: Requirement 7.2 - Redirect to re-authentication if token is invalid
    func checkAuthStatus() {
        // First check the auth service for stored token
        if let token = authService.getStoredToken() {
            if token.isExpired {
                // Validates: Requirement 1.5 - Notify user to re-authenticate if token expires
                // Validates: Requirement 7.2 - Redirect to re-authentication if token is invalid
                handleExpiredToken()
            } else {
                isAuthenticated = true
                needsCompanionAuth = false
                error = nil
                
                // Check if token needs refresh soon
                if token.needsRefresh {
                    Task {
                        await refreshTokenIfNeeded()
                    }
                }
            }
        } else {
            // Check for token from connectivity service (watchOS)
            checkForReceivedToken()
        }
    }
    
    /// Handles the OAuth callback URL.
    /// - Parameter url: The callback URL containing the authorization code
    func handleOAuthCallback(url: URL) async {
        isLoading = true
        error = nil
        
        do {
            let token = try await authService.handleCallback(url: url)
            
            // Sync token to Watch if on iOS
            #if os(iOS)
            connectivityService.sendToken(token)
            #endif
            
            isAuthenticated = true
            needsCompanionAuth = false
            isLoading = false
            
            // Start token refresh monitoring
            setupTokenRefreshMonitoring()
        } catch let appError as AppError {
            // Validates: Requirement 1.6 - Display error message on auth failure
            self.error = appError
            isAuthenticated = false
            isLoading = false
        } catch {
            self.error = .authenticationRequired
            isAuthenticated = false
            isLoading = false
        }
    }
    
    /// Clears the current error state.
    func clearError() {
        error = nil
    }
    
    /// Refreshes the authentication token if needed.
    /// Called automatically when token is about to expire.
    ///
    /// Validates: Requirement 1.5 - Notify user to re-authenticate if token expires
    func refreshTokenIfNeeded() async {
        guard let token = authService.getStoredToken() else {
            return
        }
        
        // Only refresh if token needs refresh
        guard token.needsRefresh else {
            return
        }
        
        do {
            let newToken = try await authService.refreshToken()
            
            // Sync refreshed token to Watch if on iOS
            #if os(iOS)
            connectivityService.sendToken(newToken)
            #endif
            
            isAuthenticated = true
            error = nil
        } catch {
            // Validates: Requirement 1.5 - Notify user to re-authenticate if token expires
            handleExpiredToken()
        }
    }
    
    // MARK: - Private Methods
    
    /// Checks for a token received via WatchConnectivity.
    /// Used primarily on watchOS to receive tokens from the iOS Companion App.
    private func checkForReceivedToken() {
        if let receivedToken = connectivityService.receiveToken() {
            if receivedToken.isExpired {
                // Validates: Requirement 1.5, 7.2
                handleExpiredToken()
            } else {
                isAuthenticated = true
                needsCompanionAuth = false
                error = nil
                isLoading = false
                
                // Start token refresh monitoring
                setupTokenRefreshMonitoring()
            }
        } else {
            // No token available
            isAuthenticated = false
            needsCompanionAuth = true
            isLoading = false
        }
    }
    
    /// Handles an expired token by notifying the user and clearing state.
    ///
    /// Validates: Requirement 1.5 - Notify user to re-authenticate if token expires
    /// Validates: Requirement 7.2 - Redirect to re-authentication if token is invalid
    private func handleExpiredToken() {
        isAuthenticated = false
        needsCompanionAuth = true
        error = .tokenExpired
        
        // Clear the expired token
        authService.clearToken()
        connectivityService.clearReceivedToken()
        
        // Stop token refresh monitoring
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
    }
    
    /// Sets up periodic monitoring for token refresh.
    /// Checks every minute if the token needs to be refreshed.
    private func setupTokenRefreshMonitoring() {
        // Invalidate existing timer
        tokenRefreshTimer?.invalidate()
        
        // Create a new timer that fires every 60 seconds
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshTokenIfNeeded()
            }
        }
    }
}

// MARK: - Mock for Testing

#if DEBUG
/// Mock implementation of AuthViewModel for testing and previews.
@MainActor
class MockAuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool
    @Published var isLoading: Bool
    @Published var error: AppError?
    @Published var needsCompanionAuth: Bool
    
    init(
        isAuthenticated: Bool = false,
        isLoading: Bool = false,
        error: AppError? = nil,
        needsCompanionAuth: Bool = false
    ) {
        self.isAuthenticated = isAuthenticated
        self.isLoading = isLoading
        self.error = error
        self.needsCompanionAuth = needsCompanionAuth
    }
    
    func login() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoading = false
        isAuthenticated = true
    }
    
    func logout() {
        isAuthenticated = false
        needsCompanionAuth = true
    }
    
    func checkAuthStatus() {
        // No-op for mock
    }
    
    func clearError() {
        error = nil
    }
}
#endif
