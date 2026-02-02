//
//  AuthServicePropertyTests.swift
//  AlexaWatchControllerTests
//
//  Property-based tests for AuthService.
//  Uses SwiftCheck framework for property-based testing.
//
//  **Validates: Requirements 1.3, 1.5, 7.2**
//

import XCTest
import SwiftCheck
@testable import AlexaWatchControllerShared

// MARK: - Test Generators

/// Generator for valid AuthTokens with non-empty tokens
private let validAuthTokenGen: Gen<AuthToken> = Gen<AuthToken>.compose { c in
    AuthToken(
        accessToken: c.generate(using: String.arbitrary.suchThat { $0.count >= 10 }),
        refreshToken: c.generate(using: String.arbitrary.suchThat { $0.count >= 10 }),
        expiresAt: c.generate(using: Date.arbitrary),
        tokenType: "Bearer"
    )
}

/// Generator for expired AuthTokens (expiresAt is in the past)
private let expiredAuthTokenGen: Gen<AuthToken> = Gen<AuthToken>.compose { c in
    // Generate a date in the past (between 1 second and 1 year ago)
    let pastTimeInterval = c.generate(using: Gen<TimeInterval>.choose((1, 31_536_000)))
    let expiredDate = Date().addingTimeInterval(-pastTimeInterval)
    
    return AuthToken(
        accessToken: c.generate(using: String.arbitrary.suchThat { $0.count >= 10 }),
        refreshToken: c.generate(using: String.arbitrary.suchThat { $0.count >= 10 }),
        expiresAt: expiredDate,
        tokenType: "Bearer"
    )
}

/// Generator for non-expired AuthTokens (expiresAt is in the future)
private let validNonExpiredAuthTokenGen: Gen<AuthToken> = Gen<AuthToken>.compose { c in
    // Generate a date in the future (between 1 second and 1 year from now)
    let futureTimeInterval = c.generate(using: Gen<TimeInterval>.choose((1, 31_536_000)))
    let futureDate = Date().addingTimeInterval(futureTimeInterval)
    
    return AuthToken(
        accessToken: c.generate(using: String.arbitrary.suchThat { $0.count >= 10 }),
        refreshToken: c.generate(using: String.arbitrary.suchThat { $0.count >= 10 }),
        expiresAt: futureDate,
        tokenType: "Bearer"
    )
}

// MARK: - AuthService Property Tests

final class AuthServicePropertyTests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var keychainService: KeychainService!
    
    override func setUp() {
        super.setUp()
        // Use a unique service name for testing to avoid conflicts with production data
        keychainService = KeychainService(serviceName: "com.test.alexawatchcontroller.property.auth.\(UUID().uuidString)")
    }
    
    override func tearDown() {
        keychainService.clearAll()
        keychainService = nil
        super.tearDown()
    }
    
    // MARK: - Property 1: Token Storage Persistence
    
    /// Feature: alexa-watch-controller, Property 1: Token Storage Persistence
    ///
    /// *For any* valid AuthToken received from OAuth callback, storing the token
    /// and then retrieving it should return an equivalent token with the same
    /// accessToken, refreshToken, and expiresAt values.
    ///
    /// **Validates: Requirements 1.3**
    func testTokenStoragePersistence() {
        // Create a fresh keychain service for each test run
        let testKeychainService = KeychainService(serviceName: "com.test.alexawatchcontroller.property1.\(UUID().uuidString)")
        defer { testKeychainService.clearAll() }
        
        property("Feature: alexa-watch-controller, Property 1: Token Storage Persistence - storing and retrieving a token preserves all values") <- forAll(validAuthTokenGen) { (token: AuthToken) in
            // Clear any existing token
            testKeychainService.delete(forKey: KeychainKeys.authToken)
            
            // Store the token
            let saveResult = testKeychainService.save(token, forKey: KeychainKeys.authToken)
            guard saveResult else {
                return false
            }
            
            // Retrieve the token
            guard let retrievedToken = testKeychainService.retrieve(AuthToken.self, forKey: KeychainKeys.authToken) else {
                return false
            }
            
            // Verify all properties are preserved
            return retrievedToken.accessToken == token.accessToken
                && retrievedToken.refreshToken == token.refreshToken
                && retrievedToken.expiresAt == token.expiresAt
                && retrievedToken.tokenType == token.tokenType
        }
    }
    
    /// Feature: alexa-watch-controller, Property 1: Token Storage Persistence (via AuthService)
    ///
    /// *For any* valid AuthToken, storing via KeychainService and retrieving via
    /// AuthService.getStoredToken() should return an equivalent token.
    ///
    /// **Validates: Requirements 1.3**
    func testTokenStoragePersistenceViaAuthService() {
        // Create fresh services for each test run
        let testKeychainService = KeychainService(serviceName: "com.test.alexawatchcontroller.property1.authservice.\(UUID().uuidString)")
        let authService = AuthService(keychainService: testKeychainService)
        defer { testKeychainService.clearAll() }
        
        property("Feature: alexa-watch-controller, Property 1: Token Storage Persistence via AuthService - getStoredToken returns equivalent token") <- forAll(validAuthTokenGen) { (token: AuthToken) in
            // Clear any existing token
            authService.clearToken()
            
            // Store the token directly via keychain (simulating OAuth callback storage)
            let saveResult = testKeychainService.save(token, forKey: KeychainKeys.authToken)
            guard saveResult else {
                return false
            }
            
            // Retrieve via AuthService
            guard let retrievedToken = authService.getStoredToken() else {
                return false
            }
            
            // Verify all properties are preserved
            return retrievedToken.accessToken == token.accessToken
                && retrievedToken.refreshToken == token.refreshToken
                && retrievedToken.expiresAt == token.expiresAt
                && retrievedToken.tokenType == token.tokenType
        }
    }
    
    /// Feature: alexa-watch-controller, Property 1: Token Storage Persistence - Multiple Store/Retrieve Cycles
    ///
    /// *For any* sequence of valid AuthTokens, storing each token and retrieving it
    /// should always return the most recently stored token.
    ///
    /// **Validates: Requirements 1.3**
    func testTokenStorageOverwrite() {
        let testKeychainService = KeychainService(serviceName: "com.test.alexawatchcontroller.property1.overwrite.\(UUID().uuidString)")
        defer { testKeychainService.clearAll() }
        
        property("Feature: alexa-watch-controller, Property 1: Token Storage Persistence - overwriting token stores new value") <- forAll(validAuthTokenGen, validAuthTokenGen) { (token1: AuthToken, token2: AuthToken) in
            // Clear any existing token
            testKeychainService.delete(forKey: KeychainKeys.authToken)
            
            // Store first token
            guard testKeychainService.save(token1, forKey: KeychainKeys.authToken) else {
                return false
            }
            
            // Store second token (overwrite)
            guard testKeychainService.save(token2, forKey: KeychainKeys.authToken) else {
                return false
            }
            
            // Retrieve should return the second token
            guard let retrievedToken = testKeychainService.retrieve(AuthToken.self, forKey: KeychainKeys.authToken) else {
                return false
            }
            
            // Verify the retrieved token matches the second (most recent) token
            return retrievedToken.accessToken == token2.accessToken
                && retrievedToken.refreshToken == token2.refreshToken
                && retrievedToken.expiresAt == token2.expiresAt
                && retrievedToken.tokenType == token2.tokenType
        }
    }
    
    // MARK: - Property 3: Expired Token Detection
    
    /// Feature: alexa-watch-controller, Property 3: Expired Token Detection
    ///
    /// *For any* AuthToken where expiresAt is in the past, the isExpired property
    /// should return true.
    ///
    /// **Validates: Requirements 1.5, 7.2**
    func testExpiredTokenDetection() {
        property("Feature: alexa-watch-controller, Property 3: Expired Token Detection - tokens with past expiresAt are detected as expired") <- forAll(expiredAuthTokenGen) { (token: AuthToken) in
            // The token's expiresAt is guaranteed to be in the past by the generator
            // Therefore isExpired should always return true
            return token.isExpired == true
        }
    }
    
    /// Feature: alexa-watch-controller, Property 3: Expired Token Detection - Non-Expired Tokens
    ///
    /// *For any* AuthToken where expiresAt is in the future, the isExpired property
    /// should return false.
    ///
    /// **Validates: Requirements 1.5, 7.2**
    func testNonExpiredTokenDetection() {
        property("Feature: alexa-watch-controller, Property 3: Expired Token Detection - tokens with future expiresAt are not expired") <- forAll(validNonExpiredAuthTokenGen) { (token: AuthToken) in
            // The token's expiresAt is guaranteed to be in the future by the generator
            // Therefore isExpired should always return false
            return token.isExpired == false
        }
    }
    
    /// Feature: alexa-watch-controller, Property 3: Expired Token Detection - AuthService.isAuthenticated
    ///
    /// *For any* AuthToken where expiresAt is in the past, storing the token and
    /// checking AuthService.isAuthenticated should return false (redirecting to re-authentication).
    ///
    /// **Validates: Requirements 1.5, 7.2**
    func testExpiredTokenRedirectsToReauthentication() {
        let testKeychainService = KeychainService(serviceName: "com.test.alexawatchcontroller.property3.reauth.\(UUID().uuidString)")
        let authService = AuthService(keychainService: testKeychainService)
        defer { testKeychainService.clearAll() }
        
        property("Feature: alexa-watch-controller, Property 3: Expired Token Detection - expired tokens cause isAuthenticated to return false") <- forAll(expiredAuthTokenGen) { (token: AuthToken) in
            // Clear any existing token
            authService.clearToken()
            
            // Store the expired token
            guard testKeychainService.save(token, forKey: KeychainKeys.authToken) else {
                return false
            }
            
            // isAuthenticated should return false for expired tokens
            // This validates that the app will redirect to re-authentication
            return authService.isAuthenticated == false
        }
    }
    
    /// Feature: alexa-watch-controller, Property 3: Expired Token Detection - Valid Token Authentication
    ///
    /// *For any* AuthToken where expiresAt is in the future, storing the token and
    /// checking AuthService.isAuthenticated should return true.
    ///
    /// **Validates: Requirements 1.5, 7.2**
    func testValidTokenAuthentication() {
        let testKeychainService = KeychainService(serviceName: "com.test.alexawatchcontroller.property3.valid.\(UUID().uuidString)")
        let authService = AuthService(keychainService: testKeychainService)
        defer { testKeychainService.clearAll() }
        
        property("Feature: alexa-watch-controller, Property 3: Expired Token Detection - valid tokens cause isAuthenticated to return true") <- forAll(validNonExpiredAuthTokenGen) { (token: AuthToken) in
            // Clear any existing token
            authService.clearToken()
            
            // Store the valid (non-expired) token
            guard testKeychainService.save(token, forKey: KeychainKeys.authToken) else {
                return false
            }
            
            // isAuthenticated should return true for valid tokens
            return authService.isAuthenticated == true
        }
    }
    
    /// Feature: alexa-watch-controller, Property 3: Expired Token Detection - Boundary Condition
    ///
    /// *For any* AuthToken, the isExpired property should be consistent with the
    /// comparison Date() >= expiresAt.
    ///
    /// **Validates: Requirements 1.5, 7.2**
    func testExpiredTokenBoundaryCondition() {
        property("Feature: alexa-watch-controller, Property 3: Expired Token Detection - isExpired is consistent with Date() >= expiresAt") <- forAll(validAuthTokenGen) { (token: AuthToken) in
            // The isExpired property should match the direct comparison
            let expectedExpired = Date() >= token.expiresAt
            return token.isExpired == expectedExpired
        }
    }
    
    /// Feature: alexa-watch-controller, Property 3: Expired Token Detection - needsRefresh implies close to expiration
    ///
    /// *For any* AuthToken where needsRefresh is true, the token is either expired
    /// or will expire within 5 minutes (300 seconds).
    ///
    /// **Validates: Requirements 1.5, 7.2**
    func testNeedsRefreshImpliesCloseToExpiration() {
        property("Feature: alexa-watch-controller, Property 3: Expired Token Detection - needsRefresh implies token expires within 5 minutes") <- forAll(validAuthTokenGen) { (token: AuthToken) in
            if token.needsRefresh {
                // If needsRefresh is true, the token should expire within 5 minutes (or already expired)
                let fiveMinutesFromNow = Date().addingTimeInterval(300)
                return token.expiresAt <= fiveMinutesFromNow
            } else {
                // If needsRefresh is false, the token should not expire within 5 minutes
                let fiveMinutesFromNow = Date().addingTimeInterval(300)
                return token.expiresAt > fiveMinutesFromNow
            }
        }
    }
}
