//
//  CacheServiceTests.swift
//  AlexaWatchControllerTests
//
//  Unit tests for CacheService implementation.
//  Validates: Requirements 5.1, 5.2, 5.3, 5.4
//

import XCTest
@testable import AlexaWatchControllerShared

final class CacheServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: CacheService!
    var testUserDefaults: UserDefaults!
    
    // MARK: - Test Lifecycle
    
    override func setUp() {
        super.setUp()
        // Create a unique UserDefaults suite for each test to ensure isolation
        let suiteName = "com.test.cacheservice.\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: suiteName)!
        sut = CacheService(userDefaults: testUserDefaults)
    }
    
    override func tearDown() {
        // Clean up the test UserDefaults
        if let suiteName = testUserDefaults.volatileDomainNames.first {
            testUserDefaults.removePersistentDomain(forName: suiteName)
        }
        testUserDefaults = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Creates a sample SmartPlug for testing
    private func createTestDevice(
        id: String = "test-device-1",
        name: String = "Test Plug",
        state: DeviceState = .off
    ) -> SmartPlug {
        SmartPlug(
            id: id,
            name: name,
            state: state,
            manufacturer: "Test Manufacturer",
            model: "Test Model",
            lastUpdated: Date()
        )
    }
    
    /// Creates a list of sample SmartPlugs for testing
    private func createTestDevices(count: Int = 3) -> [SmartPlug] {
        (0..<count).map { index in
            SmartPlug(
                id: "device-\(index)",
                name: "Device \(index)",
                state: index % 2 == 0 ? .on : .off,
                manufacturer: "Manufacturer \(index)",
                model: "Model \(index)",
                lastUpdated: Date()
            )
        }
    }
    
    // MARK: - Save Devices Tests
    
    /// Tests that devices can be saved to cache
    /// Validates: Requirement 5.1 - Cache device list locally after successful fetch
    func testSaveDevices_StoresDevicesInCache() {
        // Given
        let devices = createTestDevices(count: 3)
        
        // When
        sut.saveDevices(devices)
        
        // Then
        let loadedDevices = sut.loadDevices()
        XCTAssertNotNil(loadedDevices)
        XCTAssertEqual(loadedDevices?.count, 3)
    }
    
    /// Tests that saving devices updates the cache timestamp
    func testSaveDevices_UpdatesCacheTimestamp() {
        // Given
        let devices = createTestDevices()
        let beforeSave = Date()
        
        // When
        sut.saveDevices(devices)
        
        // Then
        let timestamp = sut.getCacheTimestamp()
        XCTAssertNotNil(timestamp)
        XCTAssertGreaterThanOrEqual(timestamp!, beforeSave)
    }
    
    /// Tests that saving empty device list works correctly
    func testSaveDevices_EmptyList_SavesSuccessfully() {
        // Given
        let devices: [SmartPlug] = []
        
        // When
        sut.saveDevices(devices)
        
        // Then
        let loadedDevices = sut.loadDevices()
        XCTAssertNotNil(loadedDevices)
        XCTAssertTrue(loadedDevices!.isEmpty)
    }
    
    /// Tests that saving devices overwrites previous cache
    func testSaveDevices_OverwritesPreviousCache() {
        // Given
        let initialDevices = createTestDevices(count: 2)
        let newDevices = createTestDevices(count: 5)
        
        // When
        sut.saveDevices(initialDevices)
        sut.saveDevices(newDevices)
        
        // Then
        let loadedDevices = sut.loadDevices()
        XCTAssertEqual(loadedDevices?.count, 5)
    }
    
    // MARK: - Load Devices Tests
    
    /// Tests that devices can be loaded from cache
    /// Validates: Requirement 5.2 - Display cached data when offline
    func testLoadDevices_ReturnsStoredDevices() {
        // Given
        let devices = createTestDevices()
        sut.saveDevices(devices)
        
        // When
        let loadedDevices = sut.loadDevices()
        
        // Then
        XCTAssertNotNil(loadedDevices)
        XCTAssertEqual(loadedDevices?.count, devices.count)
    }
    
    /// Tests that loading from empty cache returns nil
    func testLoadDevices_EmptyCache_ReturnsNil() {
        // When
        let loadedDevices = sut.loadDevices()
        
        // Then
        XCTAssertNil(loadedDevices)
    }
    
    /// Tests that device properties are preserved after cache round-trip
    func testLoadDevices_PreservesDeviceProperties() {
        // Given
        let device = createTestDevice(
            id: "unique-id-123",
            name: "Living Room Plug",
            state: .on
        )
        sut.saveDevices([device])
        
        // When
        let loadedDevices = sut.loadDevices()
        
        // Then
        XCTAssertNotNil(loadedDevices)
        XCTAssertEqual(loadedDevices?.count, 1)
        
        let loadedDevice = loadedDevices?.first
        XCTAssertEqual(loadedDevice?.id, device.id)
        XCTAssertEqual(loadedDevice?.name, device.name)
        XCTAssertEqual(loadedDevice?.state, device.state)
        XCTAssertEqual(loadedDevice?.manufacturer, device.manufacturer)
        XCTAssertEqual(loadedDevice?.model, device.model)
    }
    
    // MARK: - Cache Age Tests
    
    /// Tests that cache age is calculated correctly
    /// Validates: Requirement 5.3 - Indicate when displaying cached data
    func testGetCacheAge_ReturnsCorrectAge() {
        // Given
        let devices = createTestDevices()
        sut.saveDevices(devices)
        
        // When
        let cacheAge = sut.getCacheAge()
        
        // Then
        XCTAssertNotNil(cacheAge)
        XCTAssertGreaterThanOrEqual(cacheAge!, 0)
        XCTAssertLessThan(cacheAge!, 1) // Should be less than 1 second
    }
    
    /// Tests that cache age returns nil when no cache exists
    func testGetCacheAge_NoCache_ReturnsNil() {
        // When
        let cacheAge = sut.getCacheAge()
        
        // Then
        XCTAssertNil(cacheAge)
    }
    
    // MARK: - Cache Staleness Tests
    
    /// Tests that fresh cache is not stale
    /// Validates: Requirement 5.4 - Prompt refresh if cache older than 24 hours
    func testIsCacheStale_FreshCache_ReturnsFalse() {
        // Given
        let devices = createTestDevices()
        sut.saveDevices(devices)
        
        // When
        let isStale = sut.isCacheStale()
        
        // Then
        XCTAssertFalse(isStale)
    }
    
    /// Tests that no cache is considered stale
    func testIsCacheStale_NoCache_ReturnsTrue() {
        // When
        let isStale = sut.isCacheStale()
        
        // Then
        XCTAssertTrue(isStale)
    }
    
    /// Tests staleness detection with manually created stale cache
    func testIsCacheStale_OldCache_ReturnsTrue() {
        // Given - Create a cache with a timestamp older than 24 hours
        let staleDate = Date().addingTimeInterval(-CachedDeviceList.cacheExpirationInterval - 1)
        let staleCache = CachedDeviceList(devices: createTestDevices(), cachedAt: staleDate)
        
        // Manually encode and store the stale cache
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(staleCache) {
            testUserDefaults.set(data, forKey: "cachedDeviceList")
        }
        
        // When
        let isStale = sut.isCacheStale()
        
        // Then
        XCTAssertTrue(isStale)
    }
    
    // MARK: - Clear Cache Tests
    
    /// Tests that clearing cache removes all cached data
    func testClearCache_RemovesAllCachedData() {
        // Given
        let devices = createTestDevices()
        sut.saveDevices(devices)
        XCTAssertNotNil(sut.loadDevices())
        
        // When
        sut.clearCache()
        
        // Then
        XCTAssertNil(sut.loadDevices())
        XCTAssertNil(sut.getCacheAge())
        XCTAssertNil(sut.getCacheTimestamp())
    }
    
    /// Tests that clearing empty cache doesn't cause errors
    func testClearCache_EmptyCache_NoError() {
        // When/Then - Should not throw
        sut.clearCache()
        
        XCTAssertNil(sut.loadDevices())
    }
    
    // MARK: - Cache Timestamp Tests
    
    /// Tests that cache timestamp is returned correctly
    func testGetCacheTimestamp_ReturnsCorrectTimestamp() {
        // Given
        let beforeSave = Date()
        let devices = createTestDevices()
        sut.saveDevices(devices)
        let afterSave = Date()
        
        // When
        let timestamp = sut.getCacheTimestamp()
        
        // Then
        XCTAssertNotNil(timestamp)
        XCTAssertGreaterThanOrEqual(timestamp!, beforeSave)
        XCTAssertLessThanOrEqual(timestamp!, afterSave)
    }
    
    /// Tests that cache timestamp returns nil when no cache exists
    func testGetCacheTimestamp_NoCache_ReturnsNil() {
        // When
        let timestamp = sut.getCacheTimestamp()
        
        // Then
        XCTAssertNil(timestamp)
    }
    
    // MARK: - Load Cached Device List Tests
    
    /// Tests that full cached device list with metadata is returned
    func testLoadCachedDeviceList_ReturnsFullMetadata() {
        // Given
        let devices = createTestDevices()
        sut.saveDevices(devices)
        
        // When
        let cachedList = sut.loadCachedDeviceList()
        
        // Then
        XCTAssertNotNil(cachedList)
        XCTAssertEqual(cachedList?.devices.count, devices.count)
        XCTAssertNotNil(cachedList?.cachedAt)
    }
    
    /// Tests that cached device list returns nil when no cache exists
    func testLoadCachedDeviceList_NoCache_ReturnsNil() {
        // When
        let cachedList = sut.loadCachedDeviceList()
        
        // Then
        XCTAssertNil(cachedList)
    }
    
    // MARK: - Data Integrity Tests
    
    /// Tests that all device states are preserved correctly
    func testCacheRoundTrip_PreservesAllDeviceStates() {
        // Given
        let devices = [
            SmartPlug(id: "1", name: "On Device", state: .on, lastUpdated: Date()),
            SmartPlug(id: "2", name: "Off Device", state: .off, lastUpdated: Date()),
            SmartPlug(id: "3", name: "Unknown Device", state: .unknown, lastUpdated: Date())
        ]
        
        // When
        sut.saveDevices(devices)
        let loadedDevices = sut.loadDevices()
        
        // Then
        XCTAssertNotNil(loadedDevices)
        XCTAssertEqual(loadedDevices?.count, 3)
        
        XCTAssertEqual(loadedDevices?[0].state, .on)
        XCTAssertEqual(loadedDevices?[1].state, .off)
        XCTAssertEqual(loadedDevices?[2].state, .unknown)
    }
    
    /// Tests that devices with nil optional properties are handled correctly
    func testCacheRoundTrip_HandlesNilOptionalProperties() {
        // Given
        let device = SmartPlug(
            id: "minimal-device",
            name: "Minimal",
            state: .off,
            manufacturer: nil,
            model: nil,
            lastUpdated: Date()
        )
        
        // When
        sut.saveDevices([device])
        let loadedDevices = sut.loadDevices()
        
        // Then
        XCTAssertNotNil(loadedDevices)
        XCTAssertEqual(loadedDevices?.count, 1)
        
        let loadedDevice = loadedDevices?.first
        XCTAssertNil(loadedDevice?.manufacturer)
        XCTAssertNil(loadedDevice?.model)
    }
    
    /// Tests that large device lists are handled correctly
    func testCacheRoundTrip_HandlesLargeDeviceList() {
        // Given
        let devices = createTestDevices(count: 100)
        
        // When
        sut.saveDevices(devices)
        let loadedDevices = sut.loadDevices()
        
        // Then
        XCTAssertNotNil(loadedDevices)
        XCTAssertEqual(loadedDevices?.count, 100)
    }
}

// MARK: - MockCacheService Tests

final class MockCacheServiceTests: XCTestCase {
    
    var sut: MockCacheService!
    
    override func setUp() {
        super.setUp()
        sut = MockCacheService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    /// Creates a sample SmartPlug for testing
    private func createTestDevice() -> SmartPlug {
        SmartPlug(
            id: "test-device",
            name: "Test Plug",
            state: .off,
            lastUpdated: Date()
        )
    }
    
    func testMockCacheService_SaveAndLoad() {
        // Given
        let devices = [createTestDevice()]
        
        // When
        sut.saveDevices(devices)
        let loadedDevices = sut.loadDevices()
        
        // Then
        XCTAssertNotNil(loadedDevices)
        XCTAssertEqual(loadedDevices?.count, 1)
        XCTAssertEqual(sut.saveCallCount, 1)
        XCTAssertEqual(sut.loadCallCount, 1)
    }
    
    func testMockCacheService_SimulateLoadFailure() {
        // Given
        let devices = [createTestDevice()]
        sut.saveDevices(devices)
        sut.shouldFailOnLoad = true
        
        // When
        let loadedDevices = sut.loadDevices()
        
        // Then
        XCTAssertNil(loadedDevices)
    }
    
    func testMockCacheService_SetupStaleCache() {
        // Given
        let devices = [createTestDevice()]
        
        // When
        sut.setupStaleCache(devices: devices)
        
        // Then
        XCTAssertTrue(sut.isCacheStale())
    }
    
    func testMockCacheService_SetupFreshCache() {
        // Given
        let devices = [createTestDevice()]
        
        // When
        sut.setupFreshCache(devices: devices)
        
        // Then
        XCTAssertFalse(sut.isCacheStale())
    }
    
    func testMockCacheService_Reset() {
        // Given
        let devices = [createTestDevice()]
        sut.saveDevices(devices)
        sut.loadDevices()
        sut.clearCache()
        
        // When
        sut.reset()
        
        // Then
        XCTAssertNil(sut.storedCachedList)
        XCTAssertEqual(sut.saveCallCount, 0)
        XCTAssertEqual(sut.loadCallCount, 0)
        XCTAssertEqual(sut.clearCallCount, 0)
    }
}
