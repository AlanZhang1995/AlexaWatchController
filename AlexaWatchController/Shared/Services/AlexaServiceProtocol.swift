//
//  AlexaServiceProtocol.swift
//  AlexaWatchController
//
//  Protocol defining the Alexa Smart Home API service interface.
//  Validates: Requirements 2.1, 3.1, 7.1
//

import Foundation

/// Protocol defining the Alexa Smart Home API service interface.
/// Implementations handle device discovery, state retrieval, and device control
/// through the Alexa Smart Home API.
public protocol AlexaServiceProtocol {
    /// Fetches the list of smart plug devices from the Alexa API.
    /// - Returns: An array of `SmartPlug` devices associated with the user's account
    /// - Throws: `AppError.networkUnavailable` if network is unavailable
    /// - Throws: `AppError.authenticationRequired` if no valid token exists
    /// - Throws: `AppError.apiError` if the API returns an error
    /// - Validates: Requirement 2.1 - Watch_App SHALL fetch the Device_List from the Alexa_API
    func fetchDevices() async throws -> [SmartPlug]
    
    /// Toggles the state of a smart plug device.
    /// - Parameters:
    ///   - deviceId: The unique identifier of the device to toggle
    ///   - newState: The desired new state for the device
    /// - Returns: The updated `SmartPlug` with the new state
    /// - Throws: `AppError.deviceNotFound` if the device doesn't exist
    /// - Throws: `AppError.toggleFailed` if the toggle operation fails
    /// - Throws: `AppError.networkUnavailable` if network is unavailable
    /// - Validates: Requirement 3.1 - Watch_App SHALL toggle the Device_State of that plug
    func toggleDevice(deviceId: String, newState: DeviceState) async throws -> SmartPlug
    
    /// Gets the current state of a specific device.
    /// - Parameter deviceId: The unique identifier of the device
    /// - Returns: The current `DeviceState` of the device
    /// - Throws: `AppError.deviceNotFound` if the device doesn't exist
    /// - Throws: `AppError.networkUnavailable` if network is unavailable
    func getDeviceState(deviceId: String) async throws -> DeviceState
}
