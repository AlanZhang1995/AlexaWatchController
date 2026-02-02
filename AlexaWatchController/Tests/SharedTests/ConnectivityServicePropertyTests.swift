//
//  ConnectivityServicePropertyTests.swift
//  AlexaWatchControllerTests
//
//  Property-based tests for ConnectivityService.
//  Uses SwiftCheck framework for property-based testing.
//
//  **Validates: Requirements 1.4**
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

/// Generator for AuthTokens with various token types
private let authTokenWithVariousTypesGen: Gen<AuthToken> = Gen<AuthToken>.compose { c in
    let tokenTypes = ["Bearer", "Basic", "MAC", "OAuth"]
    let tokenType = c.generate(using: Gen<String>.fromElements(of: tokenTypes))
    
    return AuthToken(
        accessToken: c.generate(using: String.arbitrary.suchThat { $0.count >= 10 }),
        refreshToken: c.generate(using: String.arbitrary.suchThat { $0.count >= 10 }),
        expiresAt: c.generate(using: Date.arbitrary),
        tokenType: tokenType
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

/// Generator for AuthTokens with special characters in tokens
private let authTokenWithSpecialCharsGen: Gen<AuthToken> = Gen<AuthToken>.compose { c in
    // Generate tokens that may contain special characters
    let specialChars = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
    let baseToken = c.generate(using: String.arbitrary.suchThat { $0.count >= 10 })
    let specialChar = c.generate(using: Gen<Character>.fromElements(of: Array(specialChars)))
    let accessToken = baseToken + String(specialChar)
    
    let baseRefresh = c.generate(using: String.arbitrary.suchThat { $0.count >= 10 })
    let specialChar2 = c.generate(using: Gen<Character>.fromElements(of: Array(specialChars)))
    let refreshToken = baseRefresh + String(specialChar2)
    
    return AuthToken(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: c.generate(using: Date.arbitrary),
        tokenType: "Bearer"
    )
}

// MARK: - ConnectivityService Property Tests

final class ConnectivityServicePropertyTests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var mockService: MockConnectivityService!
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    override func setUp() {
        super.setUp()
        mockService = MockConnectivityService()
    }
    
    override func tearDown() {
        mockService = nil
        super.tearDown()
    }
    
    // MARK: - Property 2: Token Sync Round-Trip
    
    /// Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip
    ///
    /// *For any* AuthToken stored on the Companion_App, syncing via WatchConnectivity
    /// and receiving on Watch_App should produce an equivalent token.
    ///
    /// This test validates that the token synchronization process preserves all
    /// token properties during the round-trip from iOS to watchOS.
    ///
    /// **Validates: Requirements 1.4**
    func testTokenSyncRoundTrip() {
        property("Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - syncing token preserves all values") <- forAll(validAuthTokenGen) { (token: AuthToken) in
            // Create a fresh mock service for each test
            let service = MockConnectivityService()
            
            // Simulate iOS Companion App sending token
            service.sendToken(token)
            
            // Verify the token was captured for sending
            guard let sentToken = service.sentToken else {
                return false
            }
            
            // Simulate Watch App receiving the token
            // In real scenario, WatchConnectivity would transfer this
            service.mockReceivedToken = sentToken
            
            // Receive the token on Watch App side
            guard let receivedToken = service.receiveToken() else {
                return false
            }
            
            // Verify all properties are preserved during round-trip
            return receivedToken.accessToken == token.accessToken
                && receivedToken.refreshToken == token.refreshToken
                && receivedToken.expiresAt == token.expiresAt
                && receivedToken.tokenType == token.tokenType
        }
    }
    
    /// Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - Encoding/Decoding
    ///
    /// *For any* AuthToken, encoding to Data (as done in WatchConnectivity) and
    /// decoding back should produce an equivalent token.
    ///
    /// This validates the JSON serialization used in the actual WatchConnectivity
    /// message transfer.
    ///
    /// **Validates: Requirements 1.4**
    func testTokenSyncRoundTripWithEncoding() {
        let encoder = self.encoder
        let decoder = self.decoder
        property("Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - encoding/decoding preserves all values") <- forAll(validAuthTokenGen) { (token: AuthToken) in
            // Encode the token (as done when sending via WatchConnectivity)
            guard let encodedData = try? encoder.encode(token) else {
                return false
            }
            
            // Decode the token (as done when receiving via WatchConnectivity)
            guard let decodedToken = try? decoder.decode(AuthToken.self, from: encodedData) else {
                return false
            }
            
            // Verify all properties are preserved
            return decodedToken.accessToken == token.accessToken
                && decodedToken.refreshToken == token.refreshToken
                && decodedToken.expiresAt == token.expiresAt
                && decodedToken.tokenType == token.tokenType
        }
    }
    
    /// Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - Expired Tokens
    ///
    /// *For any* expired AuthToken, syncing via WatchConnectivity should preserve
    /// the expiration state (isExpired should remain true after sync).
    ///
    /// **Validates: Requirements 1.4**
    func testTokenSyncRoundTripPreservesExpiredState() {
        property("Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - expired tokens remain expired after sync") <- forAll(expiredAuthTokenGen) { (token: AuthToken) in
            let service = MockConnectivityService()
            
            // Verify the token is expired before sync
            guard token.isExpired else {
                return false
            }
            
            // Simulate sync
            service.sendToken(token)
            service.mockReceivedToken = service.sentToken
            
            guard let receivedToken = service.receiveToken() else {
                return false
            }
            
            // Verify the token is still expired after sync
            return receivedToken.isExpired == true
                && receivedToken.expiresAt == token.expiresAt
        }
    }
    
    /// Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - Valid Tokens
    ///
    /// *For any* non-expired AuthToken, syncing via WatchConnectivity should preserve
    /// the validity state (isExpired should remain false after sync).
    ///
    /// **Validates: Requirements 1.4**
    func testTokenSyncRoundTripPreservesValidState() {
        property("Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - valid tokens remain valid after sync") <- forAll(validNonExpiredAuthTokenGen) { (token: AuthToken) in
            let service = MockConnectivityService()
            
            // Verify the token is not expired before sync
            guard !token.isExpired else {
                return false
            }
            
            // Simulate sync
            service.sendToken(token)
            service.mockReceivedToken = service.sentToken
            
            guard let receivedToken = service.receiveToken() else {
                return false
            }
            
            // Verify the token is still valid after sync
            return receivedToken.isExpired == false
                && receivedToken.expiresAt == token.expiresAt
        }
    }
    
    /// Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - Various Token Types
    ///
    /// *For any* AuthToken with various token types (Bearer, Basic, etc.),
    /// syncing should preserve the token type.
    ///
    /// **Validates: Requirements 1.4**
    func testTokenSyncRoundTripPreservesTokenType() {
        property("Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - token type is preserved") <- forAll(authTokenWithVariousTypesGen) { (token: AuthToken) in
            let service = MockConnectivityService()
            
            // Simulate sync
            service.sendToken(token)
            service.mockReceivedToken = service.sentToken
            
            guard let receivedToken = service.receiveToken() else {
                return false
            }
            
            // Verify token type is preserved
            return receivedToken.tokenType == token.tokenType
        }
    }
    
    /// Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - Special Characters
    ///
    /// *For any* AuthToken containing special characters in access/refresh tokens,
    /// syncing should preserve all characters correctly.
    ///
    /// **Validates: Requirements 1.4**
    func testTokenSyncRoundTripWithSpecialCharacters() {
        let encoder = self.encoder
        let decoder = self.decoder
        property("Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - special characters are preserved") <- forAll(authTokenWithSpecialCharsGen) { (token: AuthToken) in
            // Test with actual encoding/decoding to ensure special chars survive JSON serialization
            guard let encodedData = try? encoder.encode(token) else {
                return false
            }
            
            guard let decodedToken = try? decoder.decode(AuthToken.self, from: encodedData) else {
                return false
            }
            
            // Verify special characters are preserved
            return decodedToken.accessToken == token.accessToken
                && decodedToken.refreshToken == token.refreshToken
        }
    }
    
    /// Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - Idempotency
    ///
    /// *For any* AuthToken, syncing multiple times should always produce the same result.
    ///
    /// **Validates: Requirements 1.4**
    func testTokenSyncRoundTripIdempotency() {
        property("Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - multiple syncs produce same result") <- forAll(validAuthTokenGen) { (token: AuthToken) in
            let service = MockConnectivityService()
            
            // First sync
            service.sendToken(token)
            service.mockReceivedToken = service.sentToken
            guard let firstReceived = service.receiveToken() else {
                return false
            }
            
            // Second sync (re-send the same token)
            service.sendToken(token)
            service.mockReceivedToken = service.sentToken
            guard let secondReceived = service.receiveToken() else {
                return false
            }
            
            // Both syncs should produce equivalent tokens
            return firstReceived.accessToken == secondReceived.accessToken
                && firstReceived.refreshToken == secondReceived.refreshToken
                && firstReceived.expiresAt == secondReceived.expiresAt
                && firstReceived.tokenType == secondReceived.tokenType
        }
    }
    
    /// Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - Token Equality
    ///
    /// *For any* AuthToken, the received token should be equal to the original token
    /// (using Equatable conformance).
    ///
    /// **Validates: Requirements 1.4**
    func testTokenSyncRoundTripEquality() {
        property("Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - received token equals original") <- forAll(validAuthTokenGen) { (token: AuthToken) in
            let service = MockConnectivityService()
            
            // Simulate sync
            service.sendToken(token)
            service.mockReceivedToken = service.sentToken
            
            guard let receivedToken = service.receiveToken() else {
                return false
            }
            
            // Use Equatable to verify equality
            return receivedToken == token
        }
    }
    
    /// Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - Full Encoding Round-Trip
    ///
    /// *For any* AuthToken, the complete round-trip through encoding, transfer simulation,
    /// and decoding should preserve all token properties.
    ///
    /// **Validates: Requirements 1.4**
    func testTokenSyncFullRoundTrip() {
        let encoder = self.encoder
        let decoder = self.decoder
        property("Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - full encoding round-trip preserves token") <- forAll(validAuthTokenGen) { (token: AuthToken) in
            // Step 1: iOS Companion App encodes token for sending
            guard let encodedData = try? encoder.encode(token) else {
                return false
            }
            
            // Step 2: Simulate WatchConnectivity transfer (data is transferred as-is)
            let transferredData = encodedData
            
            // Step 3: Watch App decodes received token
            guard let receivedToken = try? decoder.decode(AuthToken.self, from: transferredData) else {
                return false
            }
            
            // Verify complete round-trip preserves all properties
            return receivedToken == token
        }
    }
}

// MARK: - Additional Connectivity Tests

final class ConnectivityServiceSyncPropertyTests: XCTestCase {
    
    // MARK: - Property 2: Token Sync Round-Trip - Sequential Syncs
    
    /// Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - Sequential Updates
    ///
    /// *For any* sequence of AuthTokens, syncing them sequentially should always
    /// result in the most recent token being available on the Watch.
    ///
    /// **Validates: Requirements 1.4**
    func testTokenSyncSequentialUpdates() {
        property("Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - sequential syncs preserve latest token") <- forAll(validAuthTokenGen, validAuthTokenGen) { (token1: AuthToken, token2: AuthToken) in
            let service = MockConnectivityService()
            
            // Sync first token
            service.sendToken(token1)
            service.mockReceivedToken = service.sentToken
            
            // Sync second token (should overwrite)
            service.sendToken(token2)
            service.mockReceivedToken = service.sentToken
            
            guard let receivedToken = service.receiveToken() else {
                return false
            }
            
            // The received token should be the second (most recent) token
            return receivedToken == token2
        }
    }
    
    /// Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - Data Integrity
    ///
    /// *For any* AuthToken, the encoded data size should be reasonable and
    /// the data should be valid JSON.
    ///
    /// **Validates: Requirements 1.4**
    func testTokenSyncDataIntegrity() {
        let encoder = JSONEncoder()
        
        property("Feature: alexa-watch-controller, Property 2: Token Sync Round-Trip - encoded data is valid JSON") <- forAll(validAuthTokenGen) { (token: AuthToken) in
            guard let encodedData = try? encoder.encode(token) else {
                return false
            }
            
            // Verify data is not empty
            guard encodedData.count > 0 else {
                return false
            }
            
            // Verify data is valid JSON
            guard let _ = try? JSONSerialization.jsonObject(with: encodedData) else {
                return false
            }
            
            return true
        }
    }
}

