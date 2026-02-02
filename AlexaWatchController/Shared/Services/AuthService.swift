//
//  AuthService.swift
//  AlexaWatchController
//
//  OAuth authentication service implementation.
//  Validates: Requirements 1.2, 1.3, 1.5
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Implementation of the authentication service for OAuth operations.
/// Handles OAuth flow initiation, callback processing, token refresh,
/// and secure token storage using Keychain.
public final class AuthService: AuthServiceProtocol {
    
    // MARK: - Properties
    
    /// Keychain service for secure token storage
    private let keychainService: KeychainService
    
    /// URL session for network requests
    private let urlSession: URLSession
    
    /// OAuth client ID (should be configured in your Amazon Developer Console)
    private let clientId: String
    
    /// OAuth client secret (should be configured in your Amazon Developer Console)
    private let clientSecret: String
    
    /// Current OAuth state for CSRF protection
    private var currentOAuthState: String?
    
    // MARK: - Initialization
    
    /// Creates a new AuthService instance.
    /// - Parameters:
    ///   - keychainService: The Keychain service for secure storage
    ///   - urlSession: The URL session for network requests
    ///   - clientId: The OAuth client ID
    ///   - clientSecret: The OAuth client secret
    public init(
        keychainService: KeychainService = KeychainService(),
        urlSession: URLSession = .shared,
        clientId: String = "",
        clientSecret: String = ""
    ) {
        self.keychainService = keychainService
        self.urlSession = urlSession
        self.clientId = clientId
        self.clientSecret = clientSecret
    }
    
    // MARK: - AuthServiceProtocol
    
    /// Checks if the user is currently authenticated with a valid token.
    public var isAuthenticated: Bool {
        guard let token = getStoredToken() else {
            return false
        }
        return !token.isExpired
    }
    
    /// Initiates the OAuth authentication flow.
    /// Opens the Amazon login page for user authentication.
    /// - Validates: Requirement 1.2 - Companion_App SHALL redirect user to Amazon's login page
    public func initiateOAuth() async throws {
        guard let authURL = getAuthorizationURL() else {
            throw AppError.authenticationRequired
        }
        
        // Store the state for later verification
        if let state = currentOAuthState {
            keychainService.save(state, forKey: KeychainKeys.oauthState)
        }
        
        // Open the authorization URL
        #if canImport(UIKit) && !os(watchOS)
        await MainActor.run {
            UIApplication.shared.open(authURL)
        }
        #endif
    }
    
    /// Returns the OAuth authorization URL for the login page.
    /// - Returns: The URL to open for OAuth authentication
    public func getAuthorizationURL() -> URL? {
        // Generate a random state for CSRF protection
        let state = UUID().uuidString
        currentOAuthState = state
        
        var components = URLComponents(string: AppConfiguration.oauthAuthorizationURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "scope", value: "alexa::all"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: AppConfiguration.oauthRedirectURI),
            URLQueryItem(name: "state", value: state)
        ]
        
        return components?.url
    }
    
    /// Handles the OAuth callback URL after user authentication.
    /// Exchanges the authorization code for access and refresh tokens.
    /// - Parameter url: The callback URL containing the authorization code
    /// - Returns: The authenticated `AuthToken`
    /// - Validates: Requirement 1.3 - Companion_App SHALL securely store the OAuth_Token
    public func handleCallback(url: URL) async throws -> AuthToken {
        // Parse the callback URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw AppError.authenticationRequired
        }
        
        // Extract authorization code and state
        let code = queryItems.first(where: { $0.name == "code" })?.value
        let state = queryItems.first(where: { $0.name == "state" })?.value
        let error = queryItems.first(where: { $0.name == "error" })?.value
        
        // Check for errors
        if let error = error {
            throw AppError.apiError("OAuth error: \(error)")
        }
        
        // Verify state matches (CSRF protection)
        let storedState = keychainService.retrieve(String.self, forKey: KeychainKeys.oauthState)
        if let state = state, state != storedState && state != currentOAuthState {
            throw AppError.authenticationRequired
        }
        
        guard let authCode = code else {
            throw AppError.authenticationRequired
        }
        
        // Exchange code for tokens
        let token = try await exchangeCodeForToken(code: authCode)
        
        // Store the token securely
        // Validates: Requirement 1.3 - Companion_App SHALL securely store the OAuth_Token
        keychainService.save(token, forKey: KeychainKeys.authToken)
        
        // Clear the OAuth state
        keychainService.delete(forKey: KeychainKeys.oauthState)
        currentOAuthState = nil
        
        return token
    }
    
    /// Refreshes the current access token using the refresh token.
    /// - Returns: A new `AuthToken` with updated access token
    /// - Validates: Requirement 1.5 - Watch_App SHALL notify user to re-authenticate if token expires
    public func refreshToken() async throws -> AuthToken {
        guard let currentToken = getStoredToken() else {
            throw AppError.authenticationRequired
        }
        
        // Build the token refresh request
        guard let tokenURL = URL(string: AppConfiguration.oauthTokenURL) else {
            throw AppError.apiError("Invalid token URL")
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": currentToken.refreshToken,
            "client_id": clientId,
            "client_secret": clientSecret
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkUnavailable
            }
            
            guard httpResponse.statusCode == 200 else {
                // Token refresh failed - user needs to re-authenticate
                // Validates: Requirement 1.5
                clearToken()
                throw AppError.tokenExpired
            }
            
            let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            let newToken = tokenResponse.toAuthToken()
            
            // Store the new token securely
            keychainService.save(newToken, forKey: KeychainKeys.authToken)
            
            return newToken
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.networkUnavailable
        }
    }
    
    /// Retrieves the currently stored authentication token.
    /// - Returns: The stored `AuthToken` if available, nil otherwise
    public func getStoredToken() -> AuthToken? {
        return keychainService.retrieve(AuthToken.self, forKey: KeychainKeys.authToken)
    }
    
    /// Clears the stored authentication token.
    /// Used for logout or when re-authentication is required.
    public func clearToken() {
        keychainService.delete(forKey: KeychainKeys.authToken)
        keychainService.delete(forKey: KeychainKeys.oauthState)
        currentOAuthState = nil
    }
    
    // MARK: - Private Methods
    
    /// Exchanges an authorization code for access and refresh tokens.
    /// - Parameter code: The authorization code from the OAuth callback
    /// - Returns: The authenticated `AuthToken`
    private func exchangeCodeForToken(code: String) async throws -> AuthToken {
        guard let tokenURL = URL(string: AppConfiguration.oauthTokenURL) else {
            throw AppError.apiError("Invalid token URL")
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": AppConfiguration.oauthRedirectURI,
            "client_id": clientId,
            "client_secret": clientSecret
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkUnavailable
            }
            
            guard httpResponse.statusCode == 200 else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw AppError.apiError("Token exchange failed: \(errorMessage)")
            }
            
            let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
            return tokenResponse.toAuthToken()
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.networkUnavailable
        }
    }
}

// MARK: - OAuth Token Response

/// Response structure from the OAuth token endpoint
private struct OAuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
    
    /// Converts the response to an AuthToken model
    func toAuthToken() -> AuthToken {
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        return AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            tokenType: tokenType
        )
    }
}
