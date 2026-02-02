//
//  CacheServicePropertyTests.swift
//  AlexaWatchControllerTests
//
//  Property-based tests for CacheService.
//  Uses SwiftCheck framework for property-based testing.
//
//  **Validates: Requirements 5.1, 5.2, 5.3, 5.4**
//

import XCTest
import SwiftCheck
@testable import AlexaWatchControllerShared

// MARK: - Test Generators

/// Generator for a list of SmartPlug devices with varying sizes
private let smartPlugListGen: Gen<[SmartPlug]> = Gen<Int>.choose((0, 20)).flatMap { count in
    Gen<[SmartPlug]>.compose { c in
        (0..<count).map { _ in
            c.generate(using: SmartPlug.arbitrary)
        }
    }
}

/// Generator for cache timestamps that are fresh (within 24 hours)
private let freshCacheTimestampGen: Gen<Date> = Gen<TimeInterval>.choose((0, CachedDeviceList.cacheExpirationInterval - 1)).map { interval in
    Date().addingTimeInterval(-interval)
}

/// Generator for cache timestamps that are stale (older than 24 hours)
private let staleCacheTimestampGen: Gen<Date> = Gen<TimeInterval>.choose((CachedDeviceList.cacheExpirationInterval + 1, CachedDeviceList.cacheExpirationInterval * 10)).map { interval in
    Date().addingTimeInterval(-interval)
}

/// Generator for CachedDeviceList with fresh timestamp
private let freshCachedDeviceListGen: Gen<CachedDeviceList> = Gen<CachedDeviceList>.compose { c in
    CachedDeviceList(
        devices: c.generate(using: smartPlugListGen),
        cachedAt: c.generate(using: freshCacheTimestampGen)
    )
}

/// Generator for CachedDeviceList with stale timestamp
private let staleCachedDeviceListGen: Gen<CachedDeviceList> = Gen<CachedDeviceList>.compose { c in
    CachedDeviceList(
        devices: c.generate(using: smartPlugListGen),
        cachedAt: c.generate(using: staleCacheTimestampGen)
    )
}

// MARK: - CacheService Property Tests

final class CacheServicePropertyTests: XCTestCase {
    
    // MARK: - Test Setup
    
    private var testUserDefaults: UserDefaults!
    private var cacheService: CacheService!
    
    override func setUp() {
        super.setUp()
        // Create a unique UserDefaults suite for each test to ensure isolation
        let suiteName = "com.test.cacheservice.property.\(UUID().uuidString)"
        testUserDefaults = UserDefaults(suiteName: suiteName)!
        cacheService = CacheService(userDefaults: testUserDefaults)
    }
    
    override func tearDown() {
        // Clean up the test UserDefaults
        cacheService.clearCache()
        testUserDefaults = nil
        cacheService = nil
        super.tearDown()
    }
    
    // MARK: - Property 10: Cache Round-Trip
    
    /// Feature: alexa-watch-controller, Property 10: Cache Round-Trip
    ///
    /// *For any* list of SmartPlug devices, saving to cache and then loading from cache
    /// should return an equivalent list with all device properties preserved.
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testCacheRoundTrip_PreservesAllDevices() {
        property("Feature: alexa-watch-controller, Property 10: Cache Round-Trip - saving and loading preserves all devices") <- forAll(smartPlugListGen) { (devices: [SmartPlug]) in
            // Create a fresh cache service for each test iteration
            let suiteName = "com.test.cacheservice.property10.\(UUID().uuidString)"
            guard let testDefaults = UserDefaults(suiteName: suiteName) else {
                return false
            }
            let service = CacheService(userDefaults: testDefaults)
            defer { service.clearCache() }
            
            // Save devices to cache
            service.saveDevices(devices)
            
            // Load devices from cache
            guard let loadedDevices = service.loadDevices() else {
                // If we saved an empty list, loadDevices should still return the empty list
                return devices.isEmpty ? false : false
            }
            
            // Verify device count is preserved
            guard loadedDevices.count == devices.count else {
                return false
            }
            
            // Verify all device properties are preserved
            for (original, loaded) in zip(devices, loadedDevices) {
                guard loaded.id == original.id
                    && loaded.name == original.name
                    && loaded.state == original.state
                    && loaded.manufacturer == original.manufacturer
                    && loaded.model == original.model
                    && loaded.lastUpdated == original.lastUpdated else {
                    return false
                }
            }
            
            return true
        }
    }
    
    /// Feature: alexa-watch-controller, Property 10: Cache Round-Trip - Device Equality
    ///
    /// *For any* list of SmartPlug devices, saving to cache and then loading from cache
    /// should return a list where each device is equal to the original according to Equatable.
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testCacheRoundTrip_DevicesAreEqual() {
        property("Feature: alexa-watch-controller, Property 10: Cache Round-Trip - loaded devices are equal to original") <- forAll(smartPlugListGen) { (devices: [SmartPlug]) in
            // Create a fresh cache service for each test iteration
            let suiteName = "com.test.cacheservice.property10.equal.\(UUID().uuidString)"
            guard let testDefaults = UserDefaults(suiteName: suiteName) else {
                return false
            }
            let service = CacheService(userDefaults: testDefaults)
            defer { service.clearCache() }
            
            // Save devices to cache
            service.saveDevices(devices)
            
            // Load devices from cache
            guard let loadedDevices = service.loadDevices() else {
                return devices.isEmpty ? false : false
            }
            
            // Verify each device is equal using Equatable
            return loadedDevices == devices
        }
    }
    
    /// Feature: alexa-watch-controller, Property 10: Cache Round-Trip - CachedDeviceList Metadata
    ///
    /// *For any* list of SmartPlug devices, saving to cache and then loading the full
    /// CachedDeviceList should preserve the device list and have a valid timestamp.
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testCacheRoundTrip_PreservesCachedDeviceListMetadata() {
        property("Feature: alexa-watch-controller, Property 10: Cache Round-Trip - CachedDeviceList metadata is preserved") <- forAll(smartPlugListGen) { (devices: [SmartPlug]) in
            // Create a fresh cache service for each test iteration
            let suiteName = "com.test.cacheservice.property10.metadata.\(UUID().uuidString)"
            guard let testDefaults = UserDefaults(suiteName: suiteName) else {
                return false
            }
            let service = CacheService(userDefaults: testDefaults)
            defer { service.clearCache() }
            
            let beforeSave = Date()
            
            // Save devices to cache
            service.saveDevices(devices)
            
            let afterSave = Date()
            
            // Load full cached device list
            guard let cachedList = service.loadCachedDeviceList() else {
                return devices.isEmpty ? false : false
            }
            
            // Verify devices are preserved
            guard cachedList.devices == devices else {
                return false
            }
            
            // Verify timestamp is within expected range
            guard cachedList.cachedAt >= beforeSave && cachedList.cachedAt <= afterSave else {
                return false
            }
            
            return true
        }
    }
    
    /// Feature: alexa-watch-controller, Property 10: Cache Round-Trip - Empty List
    ///
    /// *For any* empty list of SmartPlug devices, saving to cache and then loading
    /// should return an empty list (not nil).
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testCacheRoundTrip_EmptyListIsPreserved() {
        // Create a fresh cache service for each test iteration
        let suiteName = "com.test.cacheservice.property10.empty.\(UUID().uuidString)"
        guard let testDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create UserDefaults")
            return
        }
        let service = CacheService(userDefaults: testDefaults)
        defer { service.clearCache() }
        
        let emptyDevices: [SmartPlug] = []
        
        // Save empty list to cache
        service.saveDevices(emptyDevices)
        
        // Load devices from cache
        guard let loadedDevices = service.loadDevices() else {
            XCTFail("Failed to load devices")
            return
        }
        
        // Verify empty list is returned
        XCTAssertTrue(loadedDevices.isEmpty, "Empty list should be preserved")
    }
    
    /// Feature: alexa-watch-controller, Property 10: Cache Round-Trip - Overwrite Preserves Latest
    ///
    /// *For any* two lists of SmartPlug devices, saving the first list and then saving
    /// the second list should result in loading the second list.
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testCacheRoundTrip_OverwritePreservesLatest() {
        property("Feature: alexa-watch-controller, Property 10: Cache Round-Trip - overwrite preserves latest list") <- forAll(smartPlugListGen, smartPlugListGen) { (devices1: [SmartPlug], devices2: [SmartPlug]) in
            // Create a fresh cache service for each test iteration
            let suiteName = "com.test.cacheservice.property10.overwrite.\(UUID().uuidString)"
            guard let testDefaults = UserDefaults(suiteName: suiteName) else {
                return false
            }
            let service = CacheService(userDefaults: testDefaults)
            defer { service.clearCache() }
            
            // Save first list
            service.saveDevices(devices1)
            
            // Save second list (overwrite)
            service.saveDevices(devices2)
            
            // Load devices from cache
            guard let loadedDevices = service.loadDevices() else {
                return false
            }
            
            // Verify the second (latest) list is returned
            return loadedDevices == devices2
        }
    }
    
    // MARK: - Property 11: Cache Staleness Detection
    
    /// Feature: alexa-watch-controller, Property 11: Cache Staleness Detection
    ///
    /// *For any* cached device list older than 24 hours, the isStale property should
    /// return true, and the app should indicate the data may be outdated.
    ///
    /// **Validates: Requirements 5.3, 5.4**
    func testCacheStalenessDetection_StaleCache() {
        property("Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - cache older than 24 hours is stale") <- forAll(staleCachedDeviceListGen) { (cachedList: CachedDeviceList) in
            // The cachedAt timestamp is guaranteed to be older than 24 hours by the generator
            // Therefore isStale should always return true
            return cachedList.isStale == true
        }
    }
    
    /// Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - Fresh Cache
    ///
    /// *For any* cached device list younger than 24 hours, the isStale property should
    /// return false.
    ///
    /// **Validates: Requirements 5.3, 5.4**
    func testCacheStalenessDetection_FreshCache() {
        property("Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - cache younger than 24 hours is not stale") <- forAll(freshCachedDeviceListGen) { (cachedList: CachedDeviceList) in
            // The cachedAt timestamp is guaranteed to be within 24 hours by the generator
            // Therefore isStale should always return false
            return cachedList.isStale == false
        }
    }
    
    /// Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - CacheService.isCacheStale
    ///
    /// *For any* stale CachedDeviceList stored in CacheService, the isCacheStale()
    /// method should return true.
    ///
    /// **Validates: Requirements 5.3, 5.4**
    func testCacheStalenessDetection_CacheServiceReportsStale() {
        property("Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - CacheService.isCacheStale returns true for stale cache") <- forAll(staleCachedDeviceListGen) { (cachedList: CachedDeviceList) in
            // Create a fresh cache service for each test iteration
            let suiteName = "com.test.cacheservice.property11.stale.\(UUID().uuidString)"
            guard let testDefaults = UserDefaults(suiteName: suiteName) else {
                return false
            }
            
            // Manually encode and store the stale cache
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(cachedList) else {
                return false
            }
            testDefaults.set(data, forKey: "cachedDeviceList")
            
            let service = CacheService(userDefaults: testDefaults)
            defer { service.clearCache() }
            
            // isCacheStale should return true for stale cache
            return service.isCacheStale() == true
        }
    }
    
    /// Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - CacheService.isCacheStale Fresh
    ///
    /// *For any* fresh CachedDeviceList stored in CacheService, the isCacheStale()
    /// method should return false.
    ///
    /// **Validates: Requirements 5.3, 5.4**
    func testCacheStalenessDetection_CacheServiceReportsFresh() {
        property("Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - CacheService.isCacheStale returns false for fresh cache") <- forAll(freshCachedDeviceListGen) { (cachedList: CachedDeviceList) in
            // Create a fresh cache service for each test iteration
            let suiteName = "com.test.cacheservice.property11.fresh.\(UUID().uuidString)"
            guard let testDefaults = UserDefaults(suiteName: suiteName) else {
                return false
            }
            
            // Manually encode and store the fresh cache
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(cachedList) else {
                return false
            }
            testDefaults.set(data, forKey: "cachedDeviceList")
            
            let service = CacheService(userDefaults: testDefaults)
            defer { service.clearCache() }
            
            // isCacheStale should return false for fresh cache
            return service.isCacheStale() == false
        }
    }
    
    /// Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - Boundary Condition
    ///
    /// *For any* CachedDeviceList, the isStale property should be consistent with
    /// the comparison cacheAge > cacheExpirationInterval.
    ///
    /// **Validates: Requirements 5.3, 5.4**
    func testCacheStalenessDetection_BoundaryCondition() {
        property("Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - isStale is consistent with cacheAge > 24 hours") <- forAll(CachedDeviceList.arbitrary) { (cachedList: CachedDeviceList) in
            // The isStale property should match the direct comparison
            let expectedStale = cachedList.cacheAge > CachedDeviceList.cacheExpirationInterval
            return cachedList.isStale == expectedStale
        }
    }
    
    /// Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - No Cache is Stale
    ///
    /// When no cache exists, isCacheStale() should return true (indicating refresh is needed).
    ///
    /// **Validates: Requirements 5.3, 5.4**
    func testCacheStalenessDetection_NoCacheIsStale() {
        // Create a fresh cache service with no data
        let suiteName = "com.test.cacheservice.property11.nocache.\(UUID().uuidString)"
        guard let testDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create UserDefaults")
            return
        }
        let service = CacheService(userDefaults: testDefaults)
        
        // isCacheStale should return true when no cache exists
        XCTAssertTrue(service.isCacheStale(), "No cache should be considered stale")
    }
    
    /// Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - getCacheAge Consistency
    ///
    /// *For any* CachedDeviceList stored in CacheService, getCacheAge() should return
    /// a value consistent with the stored cachedAt timestamp.
    ///
    /// **Validates: Requirements 5.3, 5.4**
    func testCacheStalenessDetection_CacheAgeConsistency() {
        property("Feature: alexa-watch-controller, Property 11: Cache Staleness Detection - getCacheAge is consistent with stored timestamp") <- forAll(CachedDeviceList.arbitrary) { (cachedList: CachedDeviceList) in
            // Create a fresh cache service for each test iteration
            let suiteName = "com.test.cacheservice.property11.age.\(UUID().uuidString)"
            guard let testDefaults = UserDefaults(suiteName: suiteName) else {
                return false
            }
            
            // Manually encode and store the cache
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(cachedList) else {
                return false
            }
            testDefaults.set(data, forKey: "cachedDeviceList")
            
            let service = CacheService(userDefaults: testDefaults)
            defer { service.clearCache() }
            
            // getCacheAge should return a value close to the expected age
            guard let cacheAge = service.getCacheAge() else {
                return false
            }
            
            // Allow for small timing differences (up to 1 second)
            let expectedAge = Date().timeIntervalSince(cachedList.cachedAt)
            return abs(cacheAge - expectedAge) < 1.0
        }
    }
}
