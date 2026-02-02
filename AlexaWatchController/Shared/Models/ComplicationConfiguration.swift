//
//  ComplicationConfiguration.swift
//  AlexaWatchController
//
//  Configuration model for Watch face complications.
//

import Foundation

/// Configuration for a complication, associating it with a device.
public struct ComplicationConfiguration: Codable, Sendable {
    public let complicationId: String
    public let deviceId: String
    public let deviceName: String
    public var deviceState: DeviceState
    
    public init(complicationId: String, deviceId: String, deviceName: String, deviceState: DeviceState = .unknown) {
        self.complicationId = complicationId
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.deviceState = deviceState
    }
}
