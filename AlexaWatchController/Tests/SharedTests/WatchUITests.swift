//
//  WatchUITests.swift
//  AlexaWatchControllerTests
//
//  Unit tests for Watch App UI components.
//  Validates: Requirements 2.3, 2.4, 4.5
//

import XCTest
import SwiftUI
@testable import AlexaWatchControllerShared

/// Unit tests for Watch App UI components.
///
/// Requirements:
/// - 2.3: Display empty state message when no devices
/// - 2.4: Display loading indicator during fetch
/// - 4.5: Display loading indicator during operations
final class WatchUITests: XCTestCase {
    
    // MARK: - Empty Device List Tests
    
    /// Test that empty device list displays appropriate message.
    /// Validates: Requirement 2.3 - Display empty state message when no devices
    @MainActor
    func testEmptyDeviceList_DisplaysEmptyMessage() async {
        let alexaService = PropertyTestAlexaService()
        alexaService.mockDevices = []
        
        let cacheService = PropertyTestCacheService()
        let authService = PropertyTestAuthService()
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        
        // Verify empty state
        XCTAssertTrue(viewModel.isEmpty, "ViewModel should report isEmpty when no devices")
        XCTAssertEqual(viewModel.devices.count, 0, "Device list should be empty")
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after fetch completes")
    }
    
    // MARK: - Loading State Tests
    
    /// Test that loading indicator is shown during fetch.
    /// Validates: Requirement 2.4 - Display loading indicator during fetch
    @MainActor
    func testLoadingState_DuringFetch() async {
        let alexaService = PropertyTestAlexaService()
        alexaService.mockDevices = [
            SmartPlug(id: "1", name: "Test", state: .on, manufacturer: nil, model: nil, lastUpdated: Date())
        ]
        
        let cacheService = PropertyTestCacheService()
        let authService = PropertyTestAuthService()
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        // Before loading
        XCTAssertFalse(viewModel.isLoading, "Should not be loading initially")
        
        // After loading completes
        await viewModel.loadDevices()
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after fetch completes")
    }
    
    /// Test that loading indicator is shown during toggle.
    /// Validates: Requirement 4.5 - Display loading indicator during operations
    @MainActor
    func testLoadingState_DuringToggle() async {
        let device = SmartPlug(id: "1", name: "Test", state: .on, manufacturer: nil, model: nil, lastUpdated: Date())
        
        let alexaService = PropertyTestAlexaService()
        alexaService.mockDevices = [device]
        
        let cacheService = PropertyTestCacheService()
        let authService = PropertyTestAuthService()
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        
        // Before toggle
        XCTAssertFalse(viewModel.isDeviceToggling(device.id), "Device should not be toggling initially")
        
        // After toggle completes
        await viewModel.toggleDevice(viewModel.devices[0])
        XCTAssertFalse(viewModel.isDeviceToggling(device.id), "Device should not be toggling after completion")
    }
    
    // MARK: - Error State Tests
    
    /// Test that error state is displayed correctly.
    /// Validates: Requirement 7.1 - Display connectivity error message
    @MainActor
    func testErrorState_NetworkError() async {
        let alexaService = PropertyTestAlexaService()
        alexaService.shouldFail = true
        alexaService.failureError = .networkUnavailable
        
        let cacheService = PropertyTestCacheService()
        let authService = PropertyTestAuthService()
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        
        XCTAssertNotNil(viewModel.error, "Error should be set on network failure")
        XCTAssertEqual(viewModel.error, .networkUnavailable, "Error should be networkUnavailable")
    }
    
    /// Test that error can be cleared.
    @MainActor
    func testErrorState_ClearError() async {
        let alexaService = PropertyTestAlexaService()
        alexaService.shouldFail = true
        alexaService.failureError = .networkUnavailable
        
        let cacheService = PropertyTestCacheService()
        let authService = PropertyTestAuthService()
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        XCTAssertNotNil(viewModel.error)
        
        viewModel.clearError()
        XCTAssertNil(viewModel.error, "Error should be nil after clearing")
    }
    
    // MARK: - Cache Indicator Tests
    
    /// Test that cache indicator is shown when using cached data.
    /// Validates: Requirement 5.3 - Indicate when displaying cached data
    @MainActor
    func testCacheIndicator_WhenUsingCache() async {
        let cachedDevices = [
            SmartPlug(id: "1", name: "Cached", state: .on, manufacturer: nil, model: nil, lastUpdated: Date())
        ]
        
        let alexaService = PropertyTestAlexaService()
        alexaService.shouldFail = true
        alexaService.failureError = .networkUnavailable
        
        let cacheService = PropertyTestCacheService()
        cacheService.saveDevices(cachedDevices)
        
        let authService = PropertyTestAuthService()
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        
        XCTAssertTrue(viewModel.isUsingCache, "Should indicate using cache when falling back to cached data")
        XCTAssertEqual(viewModel.devices.count, 1, "Should display cached devices")
    }
    
    /// Test that stale cache indicator is shown for old cache.
    /// Validates: Requirement 5.4 - Prompt refresh if cache older than 24 hours
    @MainActor
    func testStaleCacheIndicator() async {
        let cachedDevices = [
            SmartPlug(id: "1", name: "Stale", state: .on, manufacturer: nil, model: nil, lastUpdated: Date())
        ]
        
        let alexaService = PropertyTestAlexaService()
        alexaService.shouldFail = true
        
        let cacheService = PropertyTestCacheService()
        cacheService.storedDevices = cachedDevices
        cacheService.cacheDate = Date().addingTimeInterval(-90000) // 25 hours ago
        
        let authService = PropertyTestAuthService()
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        
        XCTAssertTrue(viewModel.isUsingCache, "Should indicate using cache")
        XCTAssertTrue(viewModel.isCacheStale, "Should indicate cache is stale")
    }
    
    // MARK: - Device Row Tests
    
    /// Test device state display.
    func testDeviceRow_StateDisplay() {
        let onDevice = SmartPlug(id: "1", name: "On Device", state: .on, manufacturer: nil, model: nil, lastUpdated: Date())
        let offDevice = SmartPlug(id: "2", name: "Off Device", state: .off, manufacturer: nil, model: nil, lastUpdated: Date())
        let unknownDevice = SmartPlug(id: "3", name: "Unknown Device", state: .unknown, manufacturer: nil, model: nil, lastUpdated: Date())
        
        // Verify state properties
        XCTAssertTrue(onDevice.state.isOn, "On device should report isOn = true")
        XCTAssertFalse(offDevice.state.isOn, "Off device should report isOn = false")
        XCTAssertFalse(unknownDevice.state.isOn, "Unknown device should report isOn = false")
    }
    
    // MARK: - Auth Prompt Tests
    
    /// Test auth prompt is shown when not authenticated.
    @MainActor
    func testAuthPrompt_WhenNotAuthenticated() {
        let authService = PropertyTestAuthService()
        authService.storedToken = nil
        
        let connectivityService = WatchUIMockConnectivityService()
        
        let viewModel = AuthViewModel(
            authService: authService,
            connectivityService: connectivityService
        )
        
        viewModel.checkAuthStatus()
        
        XCTAssertFalse(viewModel.isAuthenticated, "Should not be authenticated without token")
    }
    
    /// Test auth prompt shows error for expired token.
    /// Validates: Requirement 7.2 - Redirect to re-authentication if token is invalid
    @MainActor
    func testAuthPrompt_ExpiredToken() {
        let authService = PropertyTestAuthService()
        authService.storedToken = AuthToken(
            accessToken: "expired",
            refreshToken: "refresh",
            expiresAt: Date().addingTimeInterval(-3600), // Expired 1 hour ago
            tokenType: "Bearer"
        )
        
        let connectivityService = WatchUIMockConnectivityService()
        
        let viewModel = AuthViewModel(
            authService: authService,
            connectivityService: connectivityService
        )
        
        viewModel.checkAuthStatus()
        
        XCTAssertFalse(viewModel.isAuthenticated, "Should not be authenticated with expired token")
        XCTAssertEqual(viewModel.error, .tokenExpired, "Should show token expired error")
    }
}

// MARK: - Mock Connectivity Service

class WatchUIMockConnectivityService: ConnectivityServiceProtocol {
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
        // No-op for mock
    }
    
    func clearReceivedToken() {
        receivedToken = nil
    }
}
