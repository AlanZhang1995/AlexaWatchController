//
//  DeviceState.swift
//  AlexaWatchController
//
//  Core data model representing the state of a smart plug device.
//

import Foundation

/// Represents the current state of a smart plug device.
/// Conforms to Codable for persistence and Equatable for comparison.
public enum DeviceState: String, Codable, Equatable, Sendable {
    case on = "ON"
    case off = "OFF"
    case unknown = "UNKNOWN"
    
    /// Returns true if the device is currently on.
    public var isOn: Bool {
        self == .on
    }
    
    /// Toggles the device state between on and off.
    /// If the state is unknown, it remains unchanged.
    public mutating func toggle() {
        switch self {
        case .on:
            self = .off
        case .off:
            self = .on
        case .unknown:
            // Unknown state cannot be toggled
            break
        }
    }
    
    /// Returns the toggled state without mutating the current instance.
    /// Useful for optimistic UI updates.
    public var toggled: DeviceState {
        switch self {
        case .on:
            return .off
        case .off:
            return .on
        case .unknown:
            return .unknown
        }
    }
}
