//
//  AuthToken.swift
//  AlexaWatchController
//
//  Core data model representing an OAuth authentication token.
//

import Foundation

/// Represents an OAuth authentication token for Alexa API access.
/// Conforms to Codable for persistence and Equatable for comparison.
public struct AuthToken: Codable, Equatable, Sendable {
    /// The access token used for API requests
    public let accessToken: String
    
    /// The refresh token used to obtain new access tokens
    public let refreshToken: String
    
    /// The expiration date of the access token
    public let expiresAt: Date
    
    /// The token type (typically "Bearer")
    public let tokenType: String
    
    /// Creates a new AuthToken instance.
    /// - Parameters:
    ///   - accessToken: The access token string
    ///   - refreshToken: The refresh token string
    ///   - expiresAt: The expiration date
    ///   - tokenType: The token type (defaults to "Bearer")
    public init(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date,
        tokenType: String = "Bearer"
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.tokenType = tokenType
    }
    
    /// Returns true if the token has expired.
    /// A token is considered expired if the current time is at or past the expiration time.
    public var isExpired: Bool {
        Date() >= expiresAt
    }
    
    /// Returns true if the token needs to be refreshed.
    /// Tokens should be refreshed 5 minutes (300 seconds) before expiration
    /// to ensure uninterrupted API access.
    public var needsRefresh: Bool {
        Date() >= expiresAt.addingTimeInterval(-300)
    }
    
    /// Returns the remaining time until the token expires, in seconds.
    /// Returns 0 if the token has already expired.
    public var timeUntilExpiration: TimeInterval {
        max(0, expiresAt.timeIntervalSince(Date()))
    }
    
    /// Returns the Authorization header value for API requests.
    public var authorizationHeader: String {
        "\(tokenType) \(accessToken)"
    }
}
