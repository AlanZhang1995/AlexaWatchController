//
//  DeviceViewModelPropertyTests.swift
//  AlexaWatchControllerTests
//
//  Property-based tests for DeviceViewModel.
//  Tests Properties 4, 7, 8, 9 from the design document.
//

import XCTest
import SwiftCheck
@testable import AlexaWatchControllerShared

// MARK: - Mock Services for Testing

/// Mock AlexaService for property testing
class PropertyTestAlexaService: AlexaServiceProtocol {
    var mockDevices: [SmartPlug] = []
    var shouldFail: Bool = false
    var failureError: AppError = .networkUnavailable
    var toggleShouldFail: Bool = false
    var toggleFailureError: AppError = .toggleFailed("Test failure")
    
    func fetchDevices() async throws -> [SmartPlug] {
        if shouldFail { throw failureError }
        return mockDevices
    }
    
    func toggleDevice(deviceId: String, newState: DeviceState) async throws -> SmartPlug {
        if toggleShouldFail { throw toggleFailureError }
        guard var device = mockDevices.first(where: { $0.id == deviceId }) else {
            throw AppError.deviceNotFound
        }
        device = SmartPlug(
            id: device.id,
            name: device.name,
            state: newState,
            manufacturer: device.manufacturer,
            model: device.model,
            lastUpdated: Date()
        )
        // Update mock devices
        if let index = mockDevices.firstIndex(where: { $0.id == deviceId }) {
            mockDevices[index] = device
        }
        return device
    }
    
    func getDeviceState(deviceId: String) async throws -> DeviceState {
        guard let device = mockDevices.first(where: { $0.id == deviceId }) else {
            throw AppError.deviceNotFound
        }
        return device.state
    }
}

/// Mock CacheService for property testing
class PropertyTestCacheService: CacheServiceProtocol {
    var storedDevices: [SmartPlug]?
    var cacheDate: Date?
    
    func saveDevices(_ devices: [SmartPlug]) {
        storedDevices = devices
        cacheDate = Date()
    }
    
    func loadDevices() -> [SmartPlug]? {
        return storedDevices
    }
    
    func getCacheAge() -> TimeInterval? {
        guard let date = cacheDate else { return nil }
        return Date().timeIntervalSince(date)
    }
    
    func clearCache() {
        storedDevices = nil
        cacheDate = nil
    }
    
    func isCacheStale() -> Bool {
        guard let age = getCacheAge() else { return true }
        return age > 86400 // 24 hours
    }
    
    func getCacheTimestamp() -> Date? {
        return cacheDate
    }
    
    func loadCachedDeviceList() -> CachedDeviceList? {
        guard let devices = storedDevices, let date = cacheDate else { return nil }
        return CachedDeviceList(devices: devices, cachedAt: date)
    }
}

/// Mock AuthService for property testing
class PropertyTestAuthService: AuthServiceProtocol {
    var storedToken: AuthToken?
    var shouldFail: Bool = false
    
    var isAuthenticated: Bool {
        guard let token = storedToken else { return false }
        return token.expiresAt > Date()
    }
    
    func getAuthorizationURL() -> URL? {
        return URL(string: "https://www.amazon.com/ap/oa")
    }
    
    func initiateOAuth() async throws {
        if shouldFail { throw AppError.networkUnavailable }
    }
    
    func handleCallback(url: URL) async throws -> AuthToken {
        if shouldFail { throw AppError.authenticationRequired }
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
        if shouldFail { throw AppError.tokenExpired }
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

// MARK: - Property Tests

final class DeviceViewModelPropertyTests: XCTestCase {
    
    // MARK: - Property 4: Device Fetch on Valid Auth
    
    /// **Property 4: Device Fetch on Valid Auth**
    /// *For any* app launch state with a valid (non-expired) OAuth_Token,
    /// the app should initiate a device list fetch from the Alexa API.
    ///
    /// **Validates: Requirements 2.1**
    func testProperty4_DeviceFetchOnValidAuth() {
        property("Feature: alexa-watch-controller, Property 4: Device Fetch on Valid Auth") <- forAll { (deviceCount: UInt8) in
            // Limit device count to reasonable range
            let count = Int(deviceCount % 10)
            
            // Generate test devices
            let testDevices = (0..<count).map { i in
                SmartPlug(
                    id: "device_\(i)",
                    name: "Device \(i)",
                    state: i % 2 == 0 ? .on : .off,
                    manufacturer: nil,
                    model: nil,
                    lastUpdated: Date()
                )
            }
            
            // Create mock services
            let alexaService = PropertyTestAlexaService()
            alexaService.mockDevices = testDevices
            
            let cacheService = PropertyTestCacheService()
            
            let authService = PropertyTestAuthService()
            // Set valid (non-expired) token
            authService.storedToken = AuthToken(
                accessToken: "valid_token",
                refreshToken: "refresh_token",
                expiresAt: Date().addingTimeInterval(3600), // Valid for 1 hour
                tokenType: "Bearer"
            )
            
            // Create view model and load devices
            var fetchedDevices: [SmartPlug] = []
            var loadingStateObserved = false
            
            let expectation = XCTestExpectation(description: "Load devices")
            
            Task { @MainActor in
                let viewModel = DeviceViewModel(
                    alexaService: alexaService,
                    cacheService: cacheService,
                    authService: authService
                )
                
                // Load devices (simulates app launch)
                await viewModel.loadDevices()
                
                fetchedDevices = viewModel.devices
                loadingStateObserved = !viewModel.isLoading // Should be false after load
                
                expectation.fulfill()
            }
            
            // Wait for async operation
            _ = XCTWaiter.wait(for: [expectation], timeout: 5.0)
            
            // Property: With valid auth, devices should be fetched
            return fetchedDevices.count == testDevices.count &&
                   loadingStateObserved
        }
    }
    
    // MARK: - Property 7: Toggle State Inversion
    
    /// **Property 7: Toggle State Inversion**
    /// *For any* SmartPlug with a known DeviceState (on or off),
    /// toggling the device should result in the opposite state being sent to the API
    /// and displayed upon success.
    ///
    /// **Validates: Requirements 3.1, 3.3**
    func testProperty7_ToggleStateInversion() {
        property("Feature: alexa-watch-controller, Property 7: Toggle State Inversion") <- forAll { (isOn: Bool) in
            let initialState: DeviceState = isOn ? .on : .off
            let expectedState: DeviceState = isOn ? .off : .on
            
            let testDevice = SmartPlug(
                id: "test_device",
                name: "Test Device",
                state: initialState,
                manufacturer: nil,
                model: nil,
                lastUpdated: Date()
            )
            
            // Create mock services
            let alexaService = PropertyTestAlexaService()
            alexaService.mockDevices = [testDevice]
            
            let cacheService = PropertyTestCacheService()
            let authService = PropertyTestAuthService()
            
            var resultState: DeviceState = initialState
            
            let expectation = XCTestExpectation(description: "Toggle device")
            
            Task { @MainActor in
                let viewModel = DeviceViewModel(
                    alexaService: alexaService,
                    cacheService: cacheService,
                    authService: authService
                )
                
                // First load devices
                await viewModel.loadDevices()
                
                // Then toggle
                if let device = viewModel.devices.first {
                    await viewModel.toggleDevice(device)
                    resultState = viewModel.devices.first?.state ?? initialState
                }
                
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 5.0)
            
            // Property: State should be inverted after successful toggle
            return resultState == expectedState
        }
    }
    
    // MARK: - Property 8: Toggle Failure Rollback
    
    /// **Property 8: Toggle Failure Rollback**
    /// *For any* toggle operation that fails, the displayed DeviceState
    /// should revert to the original state before the toggle attempt.
    ///
    /// **Validates: Requirements 3.4**
    func testProperty8_ToggleFailureRollback() {
        property("Feature: alexa-watch-controller, Property 8: Toggle Failure Rollback") <- forAll { (isOn: Bool) in
            let initialState: DeviceState = isOn ? .on : .off
            
            let testDevice = SmartPlug(
                id: "test_device",
                name: "Test Device",
                state: initialState,
                manufacturer: nil,
                model: nil,
                lastUpdated: Date()
            )
            
            // Create mock services with toggle failure
            let alexaService = PropertyTestAlexaService()
            alexaService.mockDevices = [testDevice]
            alexaService.toggleShouldFail = true
            alexaService.toggleFailureError = .toggleFailed("Network error")
            
            let cacheService = PropertyTestCacheService()
            let authService = PropertyTestAuthService()
            
            var resultState: DeviceState = .unknown
            var errorOccurred = false
            
            let expectation = XCTestExpectation(description: "Toggle device with failure")
            
            Task { @MainActor in
                let viewModel = DeviceViewModel(
                    alexaService: alexaService,
                    cacheService: cacheService,
                    authService: authService
                )
                
                // First load devices
                await viewModel.loadDevices()
                
                // Then toggle (should fail)
                if let device = viewModel.devices.first {
                    await viewModel.toggleDevice(device)
                    resultState = viewModel.devices.first?.state ?? .unknown
                    errorOccurred = viewModel.error != nil
                }
                
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 5.0)
            
            // Property: State should revert to original on failure
            return resultState == initialState && errorOccurred
        }
    }
    
    // MARK: - Property 9: Loading State Consistency
    
    /// **Property 9: Loading State Consistency**
    /// *For any* async operation (device fetch or toggle), the isLoading state
    /// should be true while the operation is in progress and false after completion.
    ///
    /// **Validates: Requirements 3.2, 4.5**
    func testProperty9_LoadingStateConsistency() {
        property("Feature: alexa-watch-controller, Property 9: Loading State Consistency") <- forAll { (deviceCount: UInt8) in
            let count = Int(deviceCount % 5) + 1
            
            let testDevices = (0..<count).map { i in
                SmartPlug(
                    id: "device_\(i)",
                    name: "Device \(i)",
                    state: .on,
                    manufacturer: nil,
                    model: nil,
                    lastUpdated: Date()
                )
            }
            
            let alexaService = PropertyTestAlexaService()
            alexaService.mockDevices = testDevices
            
            let cacheService = PropertyTestCacheService()
            let authService = PropertyTestAuthService()
            
            var loadingAfterFetch = true
            var loadingAfterToggle = true
            
            let expectation = XCTestExpectation(description: "Check loading states")
            
            Task { @MainActor in
                let viewModel = DeviceViewModel(
                    alexaService: alexaService,
                    cacheService: cacheService,
                    authService: authService
                )
                
                // Check loading state after fetch
                await viewModel.loadDevices()
                loadingAfterFetch = viewModel.isLoading
                
                // Check loading state after toggle
                if let device = viewModel.devices.first {
                    await viewModel.toggleDevice(device)
                    loadingAfterToggle = viewModel.isDeviceToggling(device.id)
                }
                
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 5.0)
            
            // Property: Loading should be false after operations complete
            return !loadingAfterFetch && !loadingAfterToggle
        }
    }
}

// MARK: - Unit Tests

final class DeviceViewModelTests: XCTestCase {
    
    var alexaService: PropertyTestAlexaService!
    var cacheService: PropertyTestCacheService!
    var authService: PropertyTestAuthService!
    
    override func setUp() {
        super.setUp()
        alexaService = PropertyTestAlexaService()
        cacheService = PropertyTestCacheService()
        authService = PropertyTestAuthService()
    }
    
    override func tearDown() {
        alexaService = nil
        cacheService = nil
        authService = nil
        super.tearDown()
    }
    
    // MARK: - Device Loading Tests
    
    @MainActor
    func testLoadDevices_Success() async {
        let testDevices = [
            SmartPlug(id: "1", name: "Device 1", state: .on, manufacturer: nil, model: nil, lastUpdated: Date()),
            SmartPlug(id: "2", name: "Device 2", state: .off, manufacturer: nil, model: nil, lastUpdated: Date())
        ]
        alexaService.mockDevices = testDevices
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        
        XCTAssertEqual(viewModel.devices.count, 2)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isUsingCache)
        XCTAssertNil(viewModel.error)
    }
    
    @MainActor
    func testLoadDevices_NetworkError_FallsBackToCache() async {
        let cachedDevices = [
            SmartPlug(id: "1", name: "Cached Device", state: .on, manufacturer: nil, model: nil, lastUpdated: Date())
        ]
        cacheService.saveDevices(cachedDevices)
        
        alexaService.shouldFail = true
        alexaService.failureError = .networkUnavailable
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        
        XCTAssertEqual(viewModel.devices.count, 1)
        XCTAssertTrue(viewModel.isUsingCache)
        XCTAssertNotNil(viewModel.error)
    }
    
    @MainActor
    func testLoadDevices_EmptyList() async {
        alexaService.mockDevices = []
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        
        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Toggle Tests
    
    @MainActor
    func testToggleDevice_Success() async {
        let device = SmartPlug(id: "1", name: "Test", state: .off, manufacturer: nil, model: nil, lastUpdated: Date())
        alexaService.mockDevices = [device]
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        await viewModel.toggleDevice(viewModel.devices[0])
        
        XCTAssertEqual(viewModel.devices[0].state, .on)
        XCTAssertNil(viewModel.error)
    }
    
    @MainActor
    func testToggleDevice_Failure_Rollback() async {
        let device = SmartPlug(id: "1", name: "Test", state: .on, manufacturer: nil, model: nil, lastUpdated: Date())
        alexaService.mockDevices = [device]
        alexaService.toggleShouldFail = true
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        await viewModel.toggleDevice(viewModel.devices[0])
        
        // Should rollback to original state
        XCTAssertEqual(viewModel.devices[0].state, .on)
        XCTAssertNotNil(viewModel.error)
    }
    
    // MARK: - Cache Tests
    
    @MainActor
    func testCacheStaleIndicator() async {
        // Set up stale cache (older than 24 hours)
        let staleDevices = [
            SmartPlug(id: "1", name: "Stale Device", state: .on, manufacturer: nil, model: nil, lastUpdated: Date())
        ]
        cacheService.storedDevices = staleDevices
        cacheService.cacheDate = Date().addingTimeInterval(-90000) // 25 hours ago
        
        alexaService.shouldFail = true
        
        let viewModel = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        await viewModel.loadDevices()
        
        XCTAssertTrue(viewModel.isUsingCache)
        XCTAssertTrue(viewModel.isCacheStale)
    }
}
