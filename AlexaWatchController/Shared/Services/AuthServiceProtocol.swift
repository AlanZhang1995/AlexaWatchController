//
//  AuthServiceProtocol.swift
//  AlexaWatchController
//
//  Protocol defining the authentication service interface.
//  Validates: Requirements 1.2, 1.3, 1.5
//

import Foundation

/// Protocol defining the authentication service interface for OAuth operations.
/// Implementations handle OAuth flow initiation, callback processing, token refresh,
/// and secure token storage.
public protocol AuthServiceProtocol {
    /// Initiates the OAuth authentication flow.
    /// Opens the Amazon login page for user authentication.
    /// - Throws: `AppError.networkUnavailable` if network is unavailable
    /// - Validates: Requirement 1.2 - Companion_App SHALL redirect user to Amazon's login page
    func initiateOAuth() async throws
    
    /// Handles the OAuth callback URL after user authentication.
    /// Exchanges the authorization code for access and refresh tokens.
    /// - Parameter url: The callback URL containing the authorization code
    /// - Returns: The authenticated `AuthToken`
    /// - Throws: `AppError.authenticationRequired` if callback is invalid
    /// - Validates: Requirement 1.3 - Companion_App SHALL securely store the OAuth_Token
    func handleCallback(url: URL) async throws -> AuthToken
    
    /// Refreshes the current access token using the refresh token.
    /// Should be called when the token is about to expire or has expired.
    /// - Returns: A new `AuthToken` with updated access token
    /// - Throws: `AppError.tokenExpired` if refresh fails
    /// - Validates: Requirement 1.5 - Watch_App SHALL notify user to re-authenticate if token expires
    func refreshToken() async throws -> AuthToken
    
    /// Retrieves the currently stored authentication token.
    /// - Returns: The stored `AuthToken` if available, nil otherwise
    func getStoredToken() -> AuthToken?
    
    /// Clears the stored authentication token.
    /// Used for logout or when re-authentication is required.
    func clearToken()
    
    /// Checks if the user is currently authenticated with a valid token.
    /// - Returns: `true` if a valid, non-expired token exists
    var isAuthenticated: Bool { get }
    
    /// Returns the OAuth authorization URL for the login page.
    /// - Returns: The URL to open for OAuth authentication
    func getAuthorizationURL() -> URL?
}
