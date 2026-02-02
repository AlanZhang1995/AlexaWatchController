//
//  AuthServiceTests.swift
//  AlexaWatchControllerTests
//
//  Unit tests for AuthService and KeychainService.
//  Tests OAuth flow, token storage, and token refresh functionality.
//
//  **Validates: Requirements 1.2, 1.3, 1.5**
//

import XCTest
@testable import AlexaWatchControllerShared

// MARK: - Mock URL Protocol for Network Testing

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("No request handler set")
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}

// MARK: - KeychainService Tests

final class KeychainServiceTests: XCTestCase {
    
    var keychainService: KeychainService!
    
    override func setUp() {
        super.setUp()
        // Use a unique service name for testing to avoid conflicts
        keychainService = KeychainService(serviceName: "com.test.alexawatchcontroller.keychain")
        keychainService.clearAll()
    }
    
    override func tearDown() {
        keychainService.clearAll()
        keychainService = nil
        super.tearDown()
    }
    
    // MARK: - Save and Retrieve Tests
    
    /// Tests that a token can be saved and retrieved from Keychain.
    /// **Validates: Requirement 1.3 - Companion_App SHALL securely store the OAuth_Token**
    func testSaveAndRetrieveToken() {
        // Given
        let token = AuthToken(
            accessToken: "test_access_token_12345",
            refreshToken: "test_refresh_token_67890",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
        
        // When
        let saveResult = keychainService.save(token, forKey: "testToken")
        let retrievedToken = keychainService.retrieve(AuthToken.self, forKey: "testToken")
        
        // Then
        XCTAssertTrue(saveResult, "Token should be saved successfully")
        XCTAssertNotNil(retrievedToken, "Token should be retrieved")
        XCTAssertEqual(retrievedToken?.accessToken, token.accessToken)
        XCTAssertEqual(retrievedToken?.refreshToken, token.refreshToken)
        XCTAssertEqual(retrievedToken?.tokenType, token.tokenType)
    }
    
    /// Tests that retrieving a non-existent key returns nil.
    func testRetrieveNonExistentKey() {
        // When
        let result = keychainService.retrieve(AuthToken.self, forKey: "nonExistentKey")
        
        // Then
        XCTAssertNil(result, "Should return nil for non-existent key")
    }
    
    /// Tests that a token can be deleted from Keychain.
    func testDeleteToken() {
        // Given
        let token = AuthToken(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
        keychainService.save(token, forKey: "testToken")
        
        // When
        let deleteResult = keychainService.delete(forKey: "testToken")
        let retrievedToken = keychainService.retrieve(AuthToken.self, forKey: "testToken")
        
        // Then
        XCTAssertTrue(deleteResult, "Delete should succeed")
        XCTAssertNil(retrievedToken, "Token should be deleted")
    }
    
    /// Tests that updating an existing token works correctly.
    func testUpdateToken() {
        // Given
        let originalToken = AuthToken(
            accessToken: "original_access_token",
            refreshToken: "original_refresh_token",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
        keychainService.save(originalToken, forKey: "testToken")
        
        let updatedToken = AuthToken(
            accessToken: "updated_access_token",
            refreshToken: "updated_refresh_token",
            expiresAt: Date().addingTimeInterval(7200),
            tokenType: "Bearer"
        )
        
        // When
        let updateResult = keychainService.update(updatedToken, forKey: "testToken")
        let retrievedToken = keychainService.retrieve(AuthToken.self, forKey: "testToken")
        
        // Then
        XCTAssertTrue(updateResult, "Update should succeed")
        XCTAssertEqual(retrievedToken?.accessToken, updatedToken.accessToken)
        XCTAssertEqual(retrievedToken?.refreshToken, updatedToken.refreshToken)
    }
    
    /// Tests that exists() correctly identifies stored items.
    func testExists() {
        // Given
        let token = AuthToken(
            accessToken: "test_access_token",
            refreshToken: "test_refresh_token",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
        
        // When/Then - Before save
        XCTAssertFalse(keychainService.exists(forKey: "testToken"))
        
        // When - After save
        keychainService.save(token, forKey: "testToken")
        
        // Then
        XCTAssertTrue(keychainService.exists(forKey: "testToken"))
    }
    
    /// Tests that clearAll removes all stored items.
    func testClearAll() {
        // Given
        let token1 = AuthToken(
            accessToken: "token1",
            refreshToken: "refresh1",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
        let token2 = AuthToken(
            accessToken: "token2",
            refreshToken: "refresh2",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
        keychainService.save(token1, forKey: "token1")
        keychainService.save(token2, forKey: "token2")
        
        // When
        let clearResult = keychainService.clearAll()
        
        // Then
        XCTAssertTrue(clearResult, "Clear should succeed")
        XCTAssertNil(keychainService.retrieve(AuthToken.self, forKey: "token1"))
        XCTAssertNil(keychainService.retrieve(AuthToken.self, forKey: "token2"))
    }
}

// MARK: - AuthService Tests

final class AuthServiceTests: XCTestCase {
    
    var authService: AuthService!
    var keychainService: KeychainService!
    var mockSession: URLSession!
    
    override func setUp() {
        super.setUp()
        
        // Setup mock URL session
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: configuration)
        
        // Setup keychain service with test service name
        keychainService = KeychainService(serviceName: "com.test.alexawatchcontroller.auth")
        keychainService.clearAll()
        
        // Setup auth service
        authService = AuthService(
            keychainService: keychainService,
            urlSession: mockSession,
            clientId: "test_client_id",
            clientSecret: "test_client_secret"
        )
    }
    
    override func tearDown() {
        keychainService.clearAll()
        MockURLProtocol.requestHandler = nil
        authService = nil
        keychainService = nil
        mockSession = nil
        super.tearDown()
    }
    
    // MARK: - isAuthenticated Tests
    
    /// Tests that isAuthenticated returns false when no token is stored.
    func testIsAuthenticatedWithNoToken() {
        // When/Then
        XCTAssertFalse(authService.isAuthenticated, "Should not be authenticated without token")
    }
    
    /// Tests that isAuthenticated returns true when a valid token is stored.
    func testIsAuthenticatedWithValidToken() {
        // Given
        let validToken = AuthToken(
            accessToken: "valid_access_token",
            refreshToken: "valid_refresh_token",
            expiresAt: Date().addingTimeInterval(3600), // Expires in 1 hour
            tokenType: "Bearer"
        )
        keychainService.save(validToken, forKey: KeychainKeys.authToken)
        
        // When/Then
        XCTAssertTrue(authService.isAuthenticated, "Should be authenticated with valid token")
    }
    
    /// Tests that isAuthenticated returns false when token is expired.
    /// **Validates: Requirement 1.5 - Watch_App SHALL notify user to re-authenticate if token expires**
    func testIsAuthenticatedWithExpiredToken() {
        // Given
        let expiredToken = AuthToken(
            accessToken: "expired_access_token",
            refreshToken: "expired_refresh_token",
            expiresAt: Date().addingTimeInterval(-3600), // Expired 1 hour ago
            tokenType: "Bearer"
        )
        keychainService.save(expiredToken, forKey: KeychainKeys.authToken)
        
        // When/Then
        XCTAssertFalse(authService.isAuthenticated, "Should not be authenticated with expired token")
    }
    
    // MARK: - getStoredToken Tests
    
    /// Tests that getStoredToken returns nil when no token is stored.
    func testGetStoredTokenWhenEmpty() {
        // When
        let token = authService.getStoredToken()
        
        // Then
        XCTAssertNil(token, "Should return nil when no token is stored")
    }
    
    /// Tests that getStoredToken returns the stored token.
    func testGetStoredTokenWhenExists() {
        // Given
        let storedToken = AuthToken(
            accessToken: "stored_access_token",
            refreshToken: "stored_refresh_token",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
        keychainService.save(storedToken, forKey: KeychainKeys.authToken)
        
        // When
        let retrievedToken = authService.getStoredToken()
        
        // Then
        XCTAssertNotNil(retrievedToken)
        XCTAssertEqual(retrievedToken?.accessToken, storedToken.accessToken)
        XCTAssertEqual(retrievedToken?.refreshToken, storedToken.refreshToken)
    }
    
    // MARK: - clearToken Tests
    
    /// Tests that clearToken removes the stored token.
    func testClearToken() {
        // Given
        let token = AuthToken(
            accessToken: "token_to_clear",
            refreshToken: "refresh_to_clear",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
        keychainService.save(token, forKey: KeychainKeys.authToken)
        XCTAssertNotNil(authService.getStoredToken())
        
        // When
        authService.clearToken()
        
        // Then
        XCTAssertNil(authService.getStoredToken(), "Token should be cleared")
        XCTAssertFalse(authService.isAuthenticated, "Should not be authenticated after clearing token")
    }
    
    // MARK: - getAuthorizationURL Tests
    
    /// Tests that getAuthorizationURL returns a valid URL with correct parameters.
    /// **Validates: Requirement 1.2 - Companion_App SHALL redirect user to Amazon's login page**
    func testGetAuthorizationURL() {
        // When
        let url = authService.getAuthorizationURL()
        
        // Then
        XCTAssertNotNil(url, "Authorization URL should not be nil")
        
        guard let url = url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            XCTFail("URL should have valid components")
            return
        }
        
        // Verify URL base
        XCTAssertTrue(url.absoluteString.hasPrefix(AppConfiguration.oauthAuthorizationURL))
        
        // Verify required query parameters
        let clientId = queryItems.first(where: { $0.name == "client_id" })?.value
        let responseType = queryItems.first(where: { $0.name == "response_type" })?.value
        let redirectUri = queryItems.first(where: { $0.name == "redirect_uri" })?.value
        let state = queryItems.first(where: { $0.name == "state" })?.value
        let scope = queryItems.first(where: { $0.name == "scope" })?.value
        
        XCTAssertEqual(clientId, "test_client_id")
        XCTAssertEqual(responseType, "code")
        XCTAssertEqual(redirectUri, AppConfiguration.oauthRedirectURI)
        XCTAssertNotNil(state, "State parameter should be present for CSRF protection")
        XCTAssertEqual(scope, "alexa::all")
    }
    
    // MARK: - handleCallback Tests
    
    /// Tests that handleCallback successfully exchanges code for token.
    /// **Validates: Requirement 1.3 - Companion_App SHALL securely store the OAuth_Token**
    func testHandleCallbackSuccess() async throws {
        // Given
        // First call getAuthorizationURL to set up the OAuth state
        guard let authURL = authService.getAuthorizationURL(),
              let components = URLComponents(url: authURL, resolvingAgainstBaseURL: false),
              let stateParam = components.queryItems?.first(where: { $0.name == "state" })?.value else {
            XCTFail("Failed to get authorization URL with state parameter")
            return
        }
        
        let authorizationCode = "test_auth_code"
        let callbackURL = URL(string: "\(AppConfiguration.oauthRedirectURI)?code=\(authorizationCode)&state=\(stateParam)")!
        
        // Setup mock response
        let tokenResponse = """
        {
            "access_token": "new_access_token",
            "refresh_token": "new_refresh_token",
            "expires_in": 3600,
            "token_type": "Bearer"
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, tokenResponse.data(using: .utf8)!)
        }
        
        // When
        let token = try await authService.handleCallback(url: callbackURL)
        
        // Then
        XCTAssertEqual(token.accessToken, "new_access_token")
        XCTAssertEqual(token.refreshToken, "new_refresh_token")
        XCTAssertEqual(token.tokenType, "Bearer")
        
        // Verify token is stored
        let storedToken = authService.getStoredToken()
        XCTAssertNotNil(storedToken, "Token should be stored after successful callback")
        XCTAssertEqual(storedToken?.accessToken, "new_access_token")
    }
    
    /// Tests that handleCallback throws error when callback URL has error parameter.
    func testHandleCallbackWithError() async {
        // Given
        let callbackURL = URL(string: "\(AppConfiguration.oauthRedirectURI)?error=access_denied")!
        
        // When/Then
        do {
            _ = try await authService.handleCallback(url: callbackURL)
            XCTFail("Should throw error for error callback")
        } catch let error as AppError {
            if case .apiError(let message) = error {
                XCTAssertTrue(message.contains("access_denied"))
            } else {
                XCTFail("Should throw apiError")
            }
        } catch {
            XCTFail("Should throw AppError")
        }
    }
    
    /// Tests that handleCallback throws error when no code is present.
    func testHandleCallbackWithNoCode() async {
        // Given
        let callbackURL = URL(string: "\(AppConfiguration.oauthRedirectURI)?state=test_state")!
        
        // When/Then
        do {
            _ = try await authService.handleCallback(url: callbackURL)
            XCTFail("Should throw error when no code is present")
        } catch let error as AppError {
            XCTAssertEqual(error, .authenticationRequired)
        } catch {
            XCTFail("Should throw AppError.authenticationRequired")
        }
    }
    
    // MARK: - refreshToken Tests
    
    /// Tests that refreshToken successfully refreshes an existing token.
    func testRefreshTokenSuccess() async throws {
        // Given - Store an existing token
        let existingToken = AuthToken(
            accessToken: "old_access_token",
            refreshToken: "existing_refresh_token",
            expiresAt: Date().addingTimeInterval(-60), // Expired
            tokenType: "Bearer"
        )
        keychainService.save(existingToken, forKey: KeychainKeys.authToken)
        
        // Setup mock response
        let tokenResponse = """
        {
            "access_token": "refreshed_access_token",
            "refresh_token": "new_refresh_token",
            "expires_in": 3600,
            "token_type": "Bearer"
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            // Verify refresh token is in the request body
            if let body = request.httpBody,
               let bodyString = String(data: body, encoding: .utf8) {
                XCTAssertTrue(bodyString.contains("grant_type=refresh_token"))
                XCTAssertTrue(bodyString.contains("refresh_token=existing_refresh_token"))
            }
            
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, tokenResponse.data(using: .utf8)!)
        }
        
        // When
        let newToken = try await authService.refreshToken()
        
        // Then
        XCTAssertEqual(newToken.accessToken, "refreshed_access_token")
        XCTAssertEqual(newToken.refreshToken, "new_refresh_token")
        
        // Verify new token is stored
        let storedToken = authService.getStoredToken()
        XCTAssertEqual(storedToken?.accessToken, "refreshed_access_token")
    }
    
    /// Tests that refreshToken throws error when no token is stored.
    func testRefreshTokenWithNoStoredToken() async {
        // When/Then
        do {
            _ = try await authService.refreshToken()
            XCTFail("Should throw error when no token is stored")
        } catch let error as AppError {
            XCTAssertEqual(error, .authenticationRequired)
        } catch {
            XCTFail("Should throw AppError.authenticationRequired")
        }
    }
    
    /// Tests that refreshToken throws tokenExpired when refresh fails.
    /// **Validates: Requirement 1.5 - Watch_App SHALL notify user to re-authenticate if token expires**
    func testRefreshTokenFailure() async {
        // Given - Store an existing token
        let existingToken = AuthToken(
            accessToken: "old_access_token",
            refreshToken: "invalid_refresh_token",
            expiresAt: Date().addingTimeInterval(-60),
            tokenType: "Bearer"
        )
        keychainService.save(existingToken, forKey: KeychainKeys.authToken)
        
        // Setup mock response for failure
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, "Invalid refresh token".data(using: .utf8)!)
        }
        
        // When/Then
        do {
            _ = try await authService.refreshToken()
            XCTFail("Should throw error when refresh fails")
        } catch let error as AppError {
            XCTAssertEqual(error, .tokenExpired, "Should throw tokenExpired when refresh fails")
            
            // Verify token is cleared after failed refresh
            XCTAssertNil(authService.getStoredToken(), "Token should be cleared after failed refresh")
        } catch {
            XCTFail("Should throw AppError.tokenExpired")
        }
    }
}
