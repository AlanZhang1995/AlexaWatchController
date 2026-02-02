//
//  DataModelPropertyTests.swift
//  AlexaWatchControllerTests
//
//  Property-based tests for data model encode/decode round-trips.
//  Uses SwiftCheck framework for property-based testing.
//
//  **Validates: Requirements 5.1, 5.2**
//

import XCTest
import SwiftCheck
@testable import AlexaWatchControllerShared

// MARK: - Arbitrary Implementations

extension UUID: Arbitrary {
    public static var arbitrary: Gen<UUID> {
        return Gen.pure(UUID())
    }
}

extension Date: Arbitrary {
    public static var arbitrary: Gen<Date> {
        return Gen<TimeInterval>.choose((0, 1_000_000_000)).map { Date(timeIntervalSince1970: $0) }
    }
}

extension DeviceState: Arbitrary {
    public static var arbitrary: Gen<DeviceState> {
        return Gen<DeviceState>.fromElements(of: [.on, .off, .unknown])
    }
}

extension SmartPlug: Arbitrary {
    public static var arbitrary: Gen<SmartPlug> {
        return Gen<SmartPlug>.compose { c in
            SmartPlug(
                id: c.generate(using: UUID.arbitrary.map { $0.uuidString }),
                name: c.generate(using: String.arbitrary.suchThat { !$0.isEmpty }),
                state: c.generate(),
                manufacturer: c.generate(using: String?.arbitrary),
                model: c.generate(using: String?.arbitrary),
                lastUpdated: c.generate(using: Date.arbitrary)
            )
        }
    }
}

extension AuthToken: Arbitrary {
    public static var arbitrary: Gen<AuthToken> {
        return Gen<AuthToken>.compose { c in
            AuthToken(
                accessToken: c.generate(using: String.arbitrary.suchThat { $0.count > 10 }),
                refreshToken: c.generate(using: String.arbitrary.suchThat { $0.count > 10 }),
                expiresAt: c.generate(using: Date.arbitrary),
                tokenType: "Bearer"
            )
        }
    }
}

extension CachedDeviceList: Arbitrary {
    public static var arbitrary: Gen<CachedDeviceList> {
        return Gen<CachedDeviceList>.compose { c in
            CachedDeviceList(
                devices: c.generate(using: [SmartPlug].arbitrary),
                cachedAt: c.generate(using: Date.arbitrary)
            )
        }
    }
}

// MARK: - Property Tests

final class DataModelPropertyTests: XCTestCase {
    
    // MARK: - Property 10: Cache Round-Trip
    
    /// Feature: alexa-watch-controller, Property 10: SmartPlug Cache Round-Trip
    ///
    /// *For any* SmartPlug device, encoding to JSON and then decoding should return
    /// an equivalent SmartPlug with all device properties preserved.
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testSmartPlugEncodeDecodeRoundTrip() {
        property("Feature: alexa-watch-controller, Property 10: SmartPlug encode/decode round-trip preserves all properties") <- forAll { (plug: SmartPlug) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            do {
                let encoded = try encoder.encode(plug)
                let decoded = try decoder.decode(SmartPlug.self, from: encoded)
                
                // Verify all properties are preserved
                return decoded.id == plug.id
                    && decoded.name == plug.name
                    && decoded.state == plug.state
                    && decoded.manufacturer == plug.manufacturer
                    && decoded.model == plug.model
                    && decoded.lastUpdated == plug.lastUpdated
            } catch {
                return false
            }
        }
    }
    
    /// Feature: alexa-watch-controller, Property 10: AuthToken Cache Round-Trip
    ///
    /// *For any* AuthToken, encoding to JSON and then decoding should return
    /// an equivalent AuthToken with all token properties preserved.
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testAuthTokenEncodeDecodeRoundTrip() {
        property("Feature: alexa-watch-controller, Property 10: AuthToken encode/decode round-trip preserves all properties") <- forAll { (token: AuthToken) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            do {
                let encoded = try encoder.encode(token)
                let decoded = try decoder.decode(AuthToken.self, from: encoded)
                
                // Verify all properties are preserved
                return decoded.accessToken == token.accessToken
                    && decoded.refreshToken == token.refreshToken
                    && decoded.expiresAt == token.expiresAt
                    && decoded.tokenType == token.tokenType
            } catch {
                return false
            }
        }
    }
    
    /// Feature: alexa-watch-controller, Property 10: CachedDeviceList Cache Round-Trip
    ///
    /// *For any* list of SmartPlug devices, saving to cache (encoding) and then
    /// loading from cache (decoding) should return an equivalent list with all
    /// device properties preserved.
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testCachedDeviceListEncodeDecodeRoundTrip() {
        property("Feature: alexa-watch-controller, Property 10: CachedDeviceList encode/decode round-trip preserves all properties") <- forAll { (cachedList: CachedDeviceList) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            do {
                let encoded = try encoder.encode(cachedList)
                let decoded = try decoder.decode(CachedDeviceList.self, from: encoded)
                
                // Verify cachedAt is preserved
                guard decoded.cachedAt == cachedList.cachedAt else {
                    return false
                }
                
                // Verify device count is preserved
                guard decoded.devices.count == cachedList.devices.count else {
                    return false
                }
                
                // Verify all devices are preserved with all properties
                for (original, restored) in zip(cachedList.devices, decoded.devices) {
                    guard restored.id == original.id
                        && restored.name == original.name
                        && restored.state == original.state
                        && restored.manufacturer == original.manufacturer
                        && restored.model == original.model
                        && restored.lastUpdated == original.lastUpdated else {
                        return false
                    }
                }
                
                return true
            } catch {
                return false
            }
        }
    }
    
    /// Feature: alexa-watch-controller, Property 10: DeviceState Cache Round-Trip
    ///
    /// *For any* DeviceState, encoding to JSON and then decoding should return
    /// the same DeviceState value.
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testDeviceStateEncodeDecodeRoundTrip() {
        property("Feature: alexa-watch-controller, Property 10: DeviceState encode/decode round-trip preserves value") <- forAll { (state: DeviceState) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            do {
                let encoded = try encoder.encode(state)
                let decoded = try decoder.decode(DeviceState.self, from: encoded)
                
                return decoded == state
            } catch {
                return false
            }
        }
    }
    
    // MARK: - Additional Round-Trip Properties
    
    /// Feature: alexa-watch-controller, Property 10: SmartPlug Equatable Consistency
    ///
    /// *For any* SmartPlug, encoding and decoding should produce an equal instance
    /// according to the Equatable protocol.
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testSmartPlugEquatableAfterRoundTrip() {
        property("Feature: alexa-watch-controller, Property 10: SmartPlug round-trip produces equal instance") <- forAll { (plug: SmartPlug) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            do {
                let encoded = try encoder.encode(plug)
                let decoded = try decoder.decode(SmartPlug.self, from: encoded)
                
                return decoded == plug
            } catch {
                return false
            }
        }
    }
    
    /// Feature: alexa-watch-controller, Property 10: AuthToken Equatable Consistency
    ///
    /// *For any* AuthToken, encoding and decoding should produce an equal instance
    /// according to the Equatable protocol.
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testAuthTokenEquatableAfterRoundTrip() {
        property("Feature: alexa-watch-controller, Property 10: AuthToken round-trip produces equal instance") <- forAll { (token: AuthToken) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            do {
                let encoded = try encoder.encode(token)
                let decoded = try decoder.decode(AuthToken.self, from: encoded)
                
                return decoded == token
            } catch {
                return false
            }
        }
    }
    
    /// Feature: alexa-watch-controller, Property 10: CachedDeviceList Equatable Consistency
    ///
    /// *For any* CachedDeviceList, encoding and decoding should produce an equal instance
    /// according to the Equatable protocol.
    ///
    /// **Validates: Requirements 5.1, 5.2**
    func testCachedDeviceListEquatableAfterRoundTrip() {
        property("Feature: alexa-watch-controller, Property 10: CachedDeviceList round-trip produces equal instance") <- forAll { (cachedList: CachedDeviceList) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            do {
                let encoded = try encoder.encode(cachedList)
                let decoded = try decoder.decode(CachedDeviceList.self, from: encoded)
                
                return decoded == cachedList
            } catch {
                return false
            }
        }
    }
}
