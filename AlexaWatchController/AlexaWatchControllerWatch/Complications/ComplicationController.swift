//
//  ComplicationController.swift
//  AlexaWatchControllerWatch
//
//  Complication controller for Watch face complications.
//  Validates: Requirements 6.1, 6.2, 6.3, 6.4
//

import ClockKit
import SwiftUI

/// Complication controller for Watch face complications.
///
/// Requirements:
/// - 6.1: Support circular, rectangular, corner complication styles
/// - 6.2: Display device status icon
/// - 6.3: Handle tap to toggle device
/// - 6.4: Update complication when device state changes
class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Complication Configuration
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "AlexaSmartPlug",
                displayName: "智能插座",
                supportedFamilies: [
                    .circularSmall,
                    .modularSmall,
                    .utilitarianSmall,
                    .utilitarianSmallFlat,
                    .graphicCircular,
                    .graphicCorner,
                    .graphicRectangular
                ]
            )
        ]
        handler(descriptors)
    }
    
    // MARK: - Timeline Configuration
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // Complications are updated on-demand, no end date
        handler(nil)
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        // Show placeholder when device is locked
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Get current device state from cache
        let configuration = ComplicationConfigurationManager.shared.getConfiguration(for: complication.identifier)
        let deviceState = configuration?.deviceState ?? .unknown
        let deviceName = configuration?.deviceName ?? "智能插座"
        
        let template = createTemplate(for: complication.family, state: deviceState, name: deviceName)
        
        if let template = template {
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
        } else {
            handler(nil)
        }
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // No future entries - state is updated on-demand
        handler(nil)
    }
    
    // MARK: - Placeholder Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = createTemplate(for: complication.family, state: .on, name: "智能插座")
        handler(template)
    }
    
    // MARK: - Template Creation
    
    /// Creates a complication template for the given family and device state.
    /// Validates: Requirement 6.1 - Support circular, rectangular, corner styles
    /// Validates: Requirement 6.2 - Display device status icon
    private func createTemplate(for family: CLKComplicationFamily, state: DeviceState, name: String) -> CLKComplicationTemplate? {
        switch family {
        case .circularSmall:
            return createCircularSmallTemplate(state: state)
        case .modularSmall:
            return createModularSmallTemplate(state: state)
        case .utilitarianSmall, .utilitarianSmallFlat:
            return createUtilitarianSmallTemplate(state: state, name: name)
        case .graphicCircular:
            return createGraphicCircularTemplate(state: state)
        case .graphicCorner:
            return createGraphicCornerTemplate(state: state, name: name)
        case .graphicRectangular:
            return createGraphicRectangularTemplate(state: state, name: name)
        default:
            return nil
        }
    }
    
    // MARK: - Circular Small Template
    
    private func createCircularSmallTemplate(state: DeviceState) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateCircularSmallSimpleImage(
            imageProvider: CLKImageProvider(onePieceImage: stateImage(for: state))
        )
        return template
    }
    
    // MARK: - Modular Small Template
    
    private func createModularSmallTemplate(state: DeviceState) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateModularSmallSimpleImage(
            imageProvider: CLKImageProvider(onePieceImage: stateImage(for: state))
        )
        return template
    }
    
    // MARK: - Utilitarian Small Template
    
    private func createUtilitarianSmallTemplate(state: DeviceState, name: String) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateUtilitarianSmallFlat(
            textProvider: CLKTextProvider(format: "%@ %@", stateEmoji(for: state), name)
        )
        return template
    }
    
    // MARK: - Graphic Circular Template
    
    private func createGraphicCircularTemplate(state: DeviceState) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateGraphicCircularImage(
            imageProvider: CLKFullColorImageProvider(fullColorImage: stateImage(for: state))
        )
        return template
    }
    
    // MARK: - Graphic Corner Template
    
    private func createGraphicCornerTemplate(state: DeviceState, name: String) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateGraphicCornerTextImage(
            textProvider: CLKTextProvider(format: name),
            imageProvider: CLKFullColorImageProvider(fullColorImage: stateImage(for: state))
        )
        return template
    }
    
    // MARK: - Graphic Rectangular Template
    
    private func createGraphicRectangularTemplate(state: DeviceState, name: String) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateGraphicRectangularStandardBody(
            headerImageProvider: CLKFullColorImageProvider(fullColorImage: stateImage(for: state)),
            headerTextProvider: CLKTextProvider(format: name),
            body1TextProvider: CLKTextProvider(format: stateText(for: state))
        )
        return template
    }
    
    // MARK: - Helper Methods
    
    private func stateImage(for state: DeviceState) -> UIImage {
        let symbolName: String
        let color: UIColor
        
        switch state {
        case .on:
            symbolName = "power"
            color = .green
        case .off:
            symbolName = "power"
            color = .gray
        case .unknown:
            symbolName = "questionmark"
            color = .orange
        }
        
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: symbolName, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        
        return image ?? UIImage()
    }
    
    private func stateEmoji(for state: DeviceState) -> String {
        switch state {
        case .on: return "🟢"
        case .off: return "⚪️"
        case .unknown: return "🟡"
        }
    }
    
    private func stateText(for state: DeviceState) -> String {
        switch state {
        case .on: return "已开启"
        case .off: return "已关闭"
        case .unknown: return "状态未知"
        }
    }
}

// MARK: - Complication Configuration Manager

/// Manages complication configurations and device associations.
class ComplicationConfigurationManager {
    static let shared = ComplicationConfigurationManager()
    
    private let userDefaults = UserDefaults.standard
    private let configurationsKey = "complicationConfigurations"
    
    private init() {}
    
    /// Gets the configuration for a complication.
    func getConfiguration(for complicationId: String) -> ComplicationConfiguration? {
        guard let data = userDefaults.data(forKey: configurationsKey),
              let configurations = try? JSONDecoder().decode([String: ComplicationConfiguration].self, from: data) else {
            return nil
        }
        return configurations[complicationId]
    }
    
    /// Saves a configuration for a complication.
    func saveConfiguration(_ configuration: ComplicationConfiguration, for complicationId: String) {
        var configurations = getAllConfigurations()
        configurations[complicationId] = configuration
        
        if let data = try? JSONEncoder().encode(configurations) {
            userDefaults.set(data, forKey: configurationsKey)
        }
        
        // Reload complication timeline
        reloadComplication(identifier: complicationId)
    }
    
    /// Gets all complication configurations.
    func getAllConfigurations() -> [String: ComplicationConfiguration] {
        guard let data = userDefaults.data(forKey: configurationsKey),
              let configurations = try? JSONDecoder().decode([String: ComplicationConfiguration].self, from: data) else {
            return [:]
        }
        return configurations
    }
    
    /// Updates the device state for a complication.
    /// Validates: Requirement 6.4 - Update complication when device state changes
    func updateDeviceState(deviceId: String, newState: DeviceState) {
        var configurations = getAllConfigurations()
        
        for (complicationId, var config) in configurations {
            if config.deviceId == deviceId {
                config = ComplicationConfiguration(
                    complicationId: config.complicationId,
                    deviceId: config.deviceId,
                    deviceName: config.deviceName,
                    deviceState: newState
                )
                configurations[complicationId] = config
            }
        }
        
        if let data = try? JSONEncoder().encode(configurations) {
            userDefaults.set(data, forKey: configurationsKey)
        }
        
        // Reload all affected complications
        reloadAllComplications()
    }
    
    /// Reloads a specific complication.
    private func reloadComplication(identifier: String) {
        let server = CLKComplicationServer.sharedInstance()
        for complication in server.activeComplications ?? [] {
            if complication.identifier == identifier {
                server.reloadTimeline(for: complication)
            }
        }
    }
    
    /// Reloads all active complications.
    func reloadAllComplications() {
        let server = CLKComplicationServer.sharedInstance()
        for complication in server.activeComplications ?? [] {
            server.reloadTimeline(for: complication)
        }
    }
}

