//
//  SmartPlug.swift
//  AlexaWatchController
//
//  Core data model representing an Alexa-compatible smart plug device.
//

import Foundation

/// Represents an Alexa-compatible smart plug device.
/// Conforms to Identifiable for SwiftUI lists, Codable for persistence,
/// and Equatable for comparison.
public struct SmartPlug: Identifiable, Codable, Equatable, Sendable {
    /// Unique Alexa device ID
    public let id: String
    
    /// Device display name shown to the user
    public let name: String
    
    /// Current device state (on/off/unknown)
    public var state: DeviceState
    
    /// Device manufacturer (optional)
    public let manufacturer: String?
    
    /// Device model (optional)
    public let model: String?
    
    /// Timestamp of the last state update
    public let lastUpdated: Date
    
    /// Creates a new SmartPlug instance.
    /// - Parameters:
    ///   - id: Unique Alexa device ID
    ///   - name: Device display name
    ///   - state: Current device state
    ///   - manufacturer: Device manufacturer (optional)
    ///   - model: Device model (optional)
    ///   - lastUpdated: Timestamp of last update (defaults to current time)
    public init(
        id: String,
        name: String,
        state: DeviceState,
        manufacturer: String? = nil,
        model: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.state = state
        self.manufacturer = manufacturer
        self.model = model
        self.lastUpdated = lastUpdated
    }
    
    /// Returns a copy of the smart plug with the state toggled.
    /// Useful for optimistic UI updates.
    public func withToggledState() -> SmartPlug {
        var copy = self
        copy.state = state.toggled
        return copy
    }
    
    /// Returns a copy of the smart plug with a new state.
    /// - Parameter newState: The new device state
    /// - Returns: A new SmartPlug instance with the updated state
    public func withState(_ newState: DeviceState) -> SmartPlug {
        SmartPlug(
            id: id,
            name: name,
            state: newState,
            manufacturer: manufacturer,
            model: model,
            lastUpdated: Date()
        )
    }
}
