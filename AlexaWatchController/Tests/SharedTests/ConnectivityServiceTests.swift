//
//  ConnectivityServiceTests.swift
//  AlexaWatchControllerTests
//
//  Unit tests for ConnectivityService implementation.
//  Validates: Requirements 1.4
//

import XCTest
@testable import AlexaWatchControllerShared

final class ConnectivityServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: MockConnectivityService!
    
    // MARK: - Test Lifecycle
    
    override func setUp() {
        super.setUp()
        sut = MockConnectivityService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Creates a sample AuthToken for testing
    private func createTestToken(
        accessToken: String = "test-access-token",
        refreshToken: String = "test-refresh-token",
        expiresAt: Date = Date().addingTimeInterval(3600),
        tokenType: String = "Bearer"
    ) -> AuthToken {
        AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            tokenType: tokenType
        )
    }
    
    /// Creates an expired AuthToken for testing
    private func createExpiredToken() -> AuthToken {
        AuthToken(
            accessToken: "expired-access-token",
            refreshToken: "expired-refresh-token",
            expiresAt: Date().addingTimeInterval(-3600), // 1 hour ago
            tokenType: "Bearer"
        )
    }
    
    // MARK: - Send Token Tests
    
    /// Tests that sendToken stores the token correctly
    /// Validates: Requirement 1.4 - Sync OAuth token from Companion App to Watch App
    func testSendToken_StoresTokenCorrectly() {
        // Given
        let token = createTestToken()
        
        // When
        sut.sendToken(token)
        
        // Then
        XCTAssertNotNil(sut.sentToken)
        XCTAssertEqual(sut.sentToken?.accessToken, token.accessToken)
        XCTAssertEqual(sut.sentToken?.refreshToken, token.refreshToken)
        XCTAssertEqual(sut.sentToken?.tokenType, token.tokenType)
    }
    
    /// Tests that sendToken overwrites previous token
    func testSendToken_OverwritesPreviousToken() {
        // Given
        let firstToken = createTestToken(accessToken: "first-token")
        let secondToken = createTestToken(accessToken: "second-token")
        
        // When
        sut.sendToken(firstToken)
        sut.sendToken(secondToken)
        
        // Then
        XCTAssertEqual(sut.sentToken?.accessToken, "second-token")
    }
    
    /// Tests that sendToken works with expired tokens
    func testSendToken_WorksWithExpiredToken() {
        // Given
        let expiredToken = createExpiredToken()
        
        // When
        sut.sendToken(expiredToken)
        
        // Then
        XCTAssertNotNil(sut.sentToken)
        XCTAssertTrue(sut.sentToken!.isExpired)
    }
    
    // MARK: - Receive Token Tests
    
    /// Tests that receiveToken returns the mock token
    /// Validates: Requirement 1.4 - Sync OAuth token from Companion App to Watch App
    func testReceiveToken_ReturnsMockToken() {
        // Given
        let token = createTestToken()
        sut.mockReceivedToken = token
        
        // When
        let receivedToken = sut.receiveToken()
        
        // Then
        XCTAssertNotNil(receivedToken)
        XCTAssertEqual(receivedToken?.accessToken, token.accessToken)
        XCTAssertEqual(receivedToken?.refreshToken, token.refreshToken)
    }
    
    /// Tests that receiveToken returns nil when no token is set
    func testReceiveToken_NoToken_ReturnsNil() {
        // Given
        sut.mockReceivedToken = nil
        
        // When
        let receivedToken = sut.receiveToken()
        
        // Then
        XCTAssertNil(receivedToken)
    }
    
    /// Tests that receiveToken preserves all token properties
    func testReceiveToken_PreservesAllTokenProperties() {
        // Given
        let expiresAt = Date().addingTimeInterval(7200)
        let token = AuthToken(
            accessToken: "unique-access-token-12345",
            refreshToken: "unique-refresh-token-67890",
            expiresAt: expiresAt,
            tokenType: "Bearer"
        )
        sut.mockReceivedToken = token
        
        // When
        let receivedToken = sut.receiveToken()
        
        // Then
        XCTAssertNotNil(receivedToken)
        XCTAssertEqual(receivedToken?.accessToken, "unique-access-token-12345")
        XCTAssertEqual(receivedToken?.refreshToken, "unique-refresh-token-67890")
        XCTAssertEqual(receivedToken?.tokenType, "Bearer")
        if let receivedExpiresAt = receivedToken?.expiresAt {
            XCTAssertEqual(receivedExpiresAt.timeIntervalSince1970, expiresAt.timeIntervalSince1970, accuracy: 1)
        } else {
            XCTFail("receivedToken should not be nil")
        }
    }
    
    // MARK: - Reachability Tests
    
    /// Tests that isReachable returns the mock value
    func testIsReachable_ReturnsMockValue() {
        // Given
        sut.isReachable = true
        
        // Then
        XCTAssertTrue(sut.isReachable)
        
        // When
        sut.isReachable = false
        
        // Then
        XCTAssertFalse(sut.isReachable)
    }
    
    /// Tests default reachability state
    func testIsReachable_DefaultValue() {
        // Given - fresh mock service
        let freshMock = MockConnectivityService()
        
        // Then
        XCTAssertTrue(freshMock.isReachable)
    }
    
    // MARK: - Request Token Tests
    
    /// Tests that requestToken increments the call count
    func testRequestToken_IncrementsCallCount() {
        // Given
        XCTAssertEqual(sut.tokenRequestCount, 0)
        
        // When
        sut.requestToken()
        sut.requestToken()
        sut.requestToken()
        
        // Then
        XCTAssertEqual(sut.tokenRequestCount, 3)
    }
    
    // MARK: - Clear Token Tests
    
    /// Tests that clearReceivedToken clears the mock token
    func testClearReceivedToken_ClearsMockToken() {
        // Given
        sut.mockReceivedToken = createTestToken()
        XCTAssertNotNil(sut.receiveToken())
        
        // When
        sut.clearReceivedToken()
        
        // Then
        XCTAssertNil(sut.mockReceivedToken)
        XCTAssertNil(sut.receiveToken())
    }
    
    /// Tests that clearReceivedToken increments the call count
    func testClearReceivedToken_IncrementsCallCount() {
        // Given
        XCTAssertEqual(sut.clearTokenCount, 0)
        
        // When
        sut.clearReceivedToken()
        sut.clearReceivedToken()
        
        // Then
        XCTAssertEqual(sut.clearTokenCount, 2)
    }
    
    /// Tests that clearReceivedToken works when no token exists
    func testClearReceivedToken_NoToken_NoError() {
        // Given
        sut.mockReceivedToken = nil
        
        // When/Then - Should not throw
        sut.clearReceivedToken()
        
        XCTAssertNil(sut.receiveToken())
        XCTAssertEqual(sut.clearTokenCount, 1)
    }
    
    // MARK: - Token Round-Trip Tests
    
    /// Tests that token can be sent and received correctly (simulated round-trip)
    /// Validates: Requirement 1.4 - Sync OAuth token from Companion App to Watch App
    func testTokenRoundTrip_PreservesTokenData() {
        // Given
        let originalToken = createTestToken(
            accessToken: "round-trip-access-token",
            refreshToken: "round-trip-refresh-token"
        )
        
        // When - Simulate sending from iOS
        sut.sendToken(originalToken)
        
        // Simulate receiving on watchOS (in real scenario, this would be via WatchConnectivity)
        sut.mockReceivedToken = sut.sentToken
        
        let receivedToken = sut.receiveToken()
        
        // Then
        XCTAssertNotNil(receivedToken)
        XCTAssertEqual(receivedToken?.accessToken, originalToken.accessToken)
        XCTAssertEqual(receivedToken?.refreshToken, originalToken.refreshToken)
        XCTAssertEqual(receivedToken?.tokenType, originalToken.tokenType)
    }
    
    /// Tests that multiple tokens can be sent sequentially
    func testMultipleTokenSends_LastTokenWins() {
        // Given
        let tokens = (1...5).map { index in
            createTestToken(accessToken: "token-\(index)")
        }
        
        // When
        for token in tokens {
            sut.sendToken(token)
        }
        
        // Then
        XCTAssertEqual(sut.sentToken?.accessToken, "token-5")
    }
}

// MARK: - ConnectivityServiceProtocol Tests

final class ConnectivityServiceProtocolTests: XCTestCase {
    
    /// Tests that the protocol default implementations work correctly
    func testProtocolDefaultImplementations() {
        // Given
        let mock = MockConnectivityService()
        
        // When/Then - Default implementations should not crash
        mock.requestToken()
        mock.clearReceivedToken()
        
        XCTAssertEqual(mock.tokenRequestCount, 1)
        XCTAssertEqual(mock.clearTokenCount, 1)
    }
}

// MARK: - Token Encoding/Decoding Tests

final class ConnectivityServiceEncodingTests: XCTestCase {
    
    /// Tests that AuthToken can be encoded and decoded correctly for WatchConnectivity
    func testAuthTokenEncoding_RoundTrip() {
        // Given
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let originalToken = AuthToken(
            accessToken: "encoding-test-access",
            refreshToken: "encoding-test-refresh",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
        
        // When
        let encodedData = try? encoder.encode(originalToken)
        XCTAssertNotNil(encodedData)
        
        let decodedToken = try? decoder.decode(AuthToken.self, from: encodedData!)
        
        // Then
        XCTAssertNotNil(decodedToken)
        XCTAssertEqual(decodedToken?.accessToken, originalToken.accessToken)
        XCTAssertEqual(decodedToken?.refreshToken, originalToken.refreshToken)
        XCTAssertEqual(decodedToken?.tokenType, originalToken.tokenType)
        if let decodedExpiresAt = decodedToken?.expiresAt {
            XCTAssertEqual(
                decodedExpiresAt.timeIntervalSince1970,
                originalToken.expiresAt.timeIntervalSince1970,
                accuracy: 1
            )
        } else {
            XCTFail("decodedToken should not be nil")
        }
    }
    
    /// Tests that token encoding produces valid JSON data
    func testAuthTokenEncoding_ProducesValidJSON() {
        // Given
        let encoder = JSONEncoder()
        let token = AuthToken(
            accessToken: "json-test-access",
            refreshToken: "json-test-refresh",
            expiresAt: Date(),
            tokenType: "Bearer"
        )
        
        // When
        let encodedData = try? encoder.encode(token)
        
        // Then
        XCTAssertNotNil(encodedData)
        XCTAssertGreaterThan(encodedData!.count, 0)
        
        // Verify it's valid JSON
        let jsonObject = try? JSONSerialization.jsonObject(with: encodedData!)
        XCTAssertNotNil(jsonObject)
    }
    
    /// Tests that expired token encoding/decoding preserves expiration state
    func testExpiredTokenEncoding_PreservesExpirationState() {
        // Given
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let expiredToken = AuthToken(
            accessToken: "expired-access",
            refreshToken: "expired-refresh",
            expiresAt: Date().addingTimeInterval(-3600), // 1 hour ago
            tokenType: "Bearer"
        )
        
        // When
        let encodedData = try? encoder.encode(expiredToken)
        let decodedToken = try? decoder.decode(AuthToken.self, from: encodedData!)
        
        // Then
        XCTAssertNotNil(decodedToken)
        XCTAssertTrue(decodedToken!.isExpired)
    }
}
