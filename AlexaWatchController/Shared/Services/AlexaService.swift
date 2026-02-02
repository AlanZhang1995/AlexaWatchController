//
//  AlexaService.swift
//  AlexaWatchController
//
//  Alexa Smart Home API service implementation.
//  Validates: Requirements 2.1, 3.1, 7.1
//

import Foundation

/// Implementation of the Alexa Smart Home API service.
/// Handles device discovery, state retrieval, and device control
/// through the Alexa Smart Home API.
public final class AlexaService: AlexaServiceProtocol {
    
    // MARK: - Properties
    
    /// Authentication service for token management
    private let authService: AuthServiceProtocol
    
    /// URL session for network requests
    private let urlSession: URLSession
    
    /// Base URL for the Alexa API
    private let baseURL: String
    
    // MARK: - Initialization
    
    /// Creates a new AlexaService instance.
    /// - Parameters:
    ///   - authService: The authentication service for token management
    ///   - urlSession: The URL session for network requests (defaults to shared session)
    ///   - baseURL: The base URL for the Alexa API (defaults to AppConfiguration value)
    public init(
        authService: AuthServiceProtocol,
        urlSession: URLSession = .shared,
        baseURL: String = AppConfiguration.alexaAPIBaseURL
    ) {
        self.authService = authService
        self.urlSession = urlSession
        self.baseURL = baseURL
    }
    
    /// Convenience initializer using default services.
    public convenience init() {
        self.init(authService: AuthService())
    }
    
    // MARK: - AlexaServiceProtocol
    
    /// Fetches the list of smart plug devices from the Alexa API.
    /// - Returns: An array of `SmartPlug` devices associated with the user's account
    /// - Validates: Requirement 2.1 - Watch_App SHALL fetch the Device_List from the Alexa_API
    public func fetchDevices() async throws -> [SmartPlug] {
        // Get the access token
        guard let token = authService.getStoredToken() else {
            throw AppError.authenticationRequired
        }
        
        // Check if token is expired
        if token.isExpired {
            throw AppError.tokenExpired
        }
        
        // Build the endpoint discovery request
        let endpointURL = "\(baseURL)/v1/endpoints"
        guard let url = URL(string: endpointURL) else {
            throw AppError.apiError("Invalid API URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkUnavailable
            }
            
            // Handle HTTP status codes
            // Validates: Requirement 7.1 - Handle API errors
            switch httpResponse.statusCode {
            case 200:
                // Success - parse the response
                let endpointsResponse = try JSONDecoder().decode(EndpointsResponse.self, from: data)
                return filterSmartPlugs(from: endpointsResponse.endpoints)
                
            case 401:
                // Unauthorized - token may be invalid
                throw AppError.tokenExpired
                
            case 403:
                // Forbidden - insufficient permissions
                throw AppError.apiError("权限不足，请重新授权")
                
            case 404:
                // Not found
                throw AppError.apiError("API 端点未找到")
                
            case 429:
                // Rate limited
                throw AppError.apiError("请求过于频繁，请稍后重试")
                
            case 500...599:
                // Server error
                throw AppError.apiError("服务器错误，请稍后重试")
                
            default:
                let errorMessage = parseErrorMessage(from: data) ?? "未知错误 (\(httpResponse.statusCode))"
                throw AppError.apiError(errorMessage)
            }
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            // Handle network errors
            // Validates: Requirement 7.1 - Display connectivity error message
            throw mapURLError(error)
        } catch {
            throw AppError.networkUnavailable
        }
    }
    
    /// Toggles the state of a smart plug device.
    /// - Parameters:
    ///   - deviceId: The unique identifier of the device to toggle
    ///   - newState: The desired new state for the device
    /// - Returns: The updated `SmartPlug` with the new state
    /// - Validates: Requirement 3.1 - Watch_App SHALL toggle the Device_State of that plug
    public func toggleDevice(deviceId: String, newState: DeviceState) async throws -> SmartPlug {
        // Get the access token
        guard let token = authService.getStoredToken() else {
            throw AppError.authenticationRequired
        }
        
        // Check if token is expired
        if token.isExpired {
            throw AppError.tokenExpired
        }
        
        // Validate the new state
        guard newState != .unknown else {
            throw AppError.toggleFailed("无法设置为未知状态")
        }
        
        // Build the directive request
        let directiveURL = "\(baseURL)/v1/directives"
        guard let url = URL(string: directiveURL) else {
            throw AppError.apiError("Invalid API URL")
        }
        
        // Create the power controller directive
        let directive = PowerControllerDirective(
            endpointId: deviceId,
            action: newState == .on ? "TurnOn" : "TurnOff"
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(directive)
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkUnavailable
            }
            
            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200, 202:
                // Success - return updated device
                // Note: The API may return 202 Accepted for async operations
                return SmartPlug(
                    id: deviceId,
                    name: "", // Name will be populated from cache or subsequent fetch
                    state: newState,
                    lastUpdated: Date()
                )
                
            case 401:
                throw AppError.tokenExpired
                
            case 404:
                throw AppError.deviceNotFound
                
            case 422:
                // Unprocessable entity - device may be offline
                throw AppError.toggleFailed("设备离线或无法响应")
                
            case 429:
                throw AppError.toggleFailed("请求过于频繁，请稍后重试")
                
            case 500...599:
                throw AppError.toggleFailed("服务器错误，请稍后重试")
                
            default:
                let errorMessage = parseErrorMessage(from: data) ?? "操作失败"
                throw AppError.toggleFailed(errorMessage)
            }
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            throw mapURLErrorToToggleFailed(error)
        } catch {
            throw AppError.toggleFailed("网络请求失败")
        }
    }
    
    /// Gets the current state of a specific device.
    /// - Parameter deviceId: The unique identifier of the device
    /// - Returns: The current `DeviceState` of the device
    public func getDeviceState(deviceId: String) async throws -> DeviceState {
        // Get the access token
        guard let token = authService.getStoredToken() else {
            throw AppError.authenticationRequired
        }
        
        // Check if token is expired
        if token.isExpired {
            throw AppError.tokenExpired
        }
        
        // Build the state report request
        let stateURL = "\(baseURL)/v1/endpoints/\(deviceId)/state"
        guard let url = URL(string: stateURL) else {
            throw AppError.apiError("Invalid API URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError.networkUnavailable
            }
            
            switch httpResponse.statusCode {
            case 200:
                let stateResponse = try JSONDecoder().decode(DeviceStateResponse.self, from: data)
                return stateResponse.toDeviceState()
                
            case 401:
                throw AppError.tokenExpired
                
            case 404:
                throw AppError.deviceNotFound
                
            default:
                let errorMessage = parseErrorMessage(from: data) ?? "无法获取设备状态"
                throw AppError.apiError(errorMessage)
            }
        } catch let error as AppError {
            throw error
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw AppError.networkUnavailable
        }
    }
    
    // MARK: - Private Methods
    
    /// Filters the endpoints to return only smart plug devices.
    /// - Parameter endpoints: The list of all endpoints from the API
    /// - Returns: An array of SmartPlug devices
    private func filterSmartPlugs(from endpoints: [EndpointInfo]) -> [SmartPlug] {
        return endpoints.compactMap { endpoint -> SmartPlug? in
            // Filter for smart plug display categories
            let plugCategories = ["SMARTPLUG", "SWITCH", "PLUG"]
            let isSmartPlug = endpoint.displayCategories.contains { category in
                plugCategories.contains(category.uppercased())
            }
            
            guard isSmartPlug else { return nil }
            
            // Extract the power state from capabilities
            let powerState = extractPowerState(from: endpoint.capabilities)
            
            return SmartPlug(
                id: endpoint.endpointId,
                name: endpoint.friendlyName,
                state: powerState,
                manufacturer: endpoint.manufacturerName,
                model: endpoint.description,
                lastUpdated: Date()
            )
        }
    }
    
    /// Extracts the power state from device capabilities.
    /// - Parameter capabilities: The device capabilities array
    /// - Returns: The current DeviceState
    private func extractPowerState(from capabilities: [CapabilityInfo]?) -> DeviceState {
        guard let capabilities = capabilities else {
            return .unknown
        }
        
        // Look for PowerController capability
        for capability in capabilities {
            if capability.interface == "Alexa.PowerController" {
                if let properties = capability.properties {
                    for property in properties {
                        if property.name == "powerState" {
                            if let value = property.value as? String {
                                return value.uppercased() == "ON" ? .on : .off
                            }
                        }
                    }
                }
            }
        }
        
        return .unknown
    }
    
    /// Parses an error message from API response data.
    /// - Parameter data: The response data
    /// - Returns: The error message if parseable, nil otherwise
    private func parseErrorMessage(from data: Data) -> String? {
        if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
            return errorResponse.message ?? errorResponse.error
        }
        return nil
    }
    
    /// Maps a URLError to an appropriate AppError.
    /// - Parameter error: The URLError to map
    /// - Returns: The corresponding AppError
    /// - Validates: Requirement 7.1 - Display connectivity error message
    private func mapURLError(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .networkUnavailable
        case .timedOut:
            return .apiError("请求超时，请检查网络连接")
        case .cannotFindHost, .cannotConnectToHost:
            return .apiError("无法连接到服务器")
        case .secureConnectionFailed:
            return .apiError("安全连接失败")
        default:
            return .networkUnavailable
        }
    }
    
    /// Maps a URLError to a toggle failed error.
    /// - Parameter error: The URLError to map
    /// - Returns: The corresponding AppError
    private func mapURLErrorToToggleFailed(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .toggleFailed("网络连接已断开")
        case .timedOut:
            return .toggleFailed("操作超时，请重试")
        default:
            return .toggleFailed("网络请求失败")
        }
    }
}

// MARK: - API Response Models

/// Response structure for the endpoints discovery API
private struct EndpointsResponse: Codable {
    let endpoints: [EndpointInfo]
}

/// Information about a single endpoint (device)
private struct EndpointInfo: Codable {
    let endpointId: String
    let friendlyName: String
    let description: String?
    let manufacturerName: String?
    let displayCategories: [String]
    let capabilities: [CapabilityInfo]?
}

/// Information about a device capability
private struct CapabilityInfo: Codable {
    let type: String?
    let interface: String
    let version: String?
    let properties: [PropertyInfo]?
}

/// Information about a capability property
private struct PropertyInfo: Codable {
    let name: String
    let value: AnyCodable?
    
    enum CodingKeys: String, CodingKey {
        case name
        case value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decodeIfPresent(AnyCodable.self, forKey: .value)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(value, forKey: .value)
    }
}

/// A type-erased Codable wrapper for handling dynamic JSON values
private struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        default:
            try container.encodeNil()
        }
    }
}

/// Response structure for device state queries
private struct DeviceStateResponse: Codable {
    let properties: [StateProperty]?
    
    struct StateProperty: Codable {
        let namespace: String?
        let name: String
        let value: String?
    }
    
    func toDeviceState() -> DeviceState {
        guard let properties = properties else {
            return .unknown
        }
        
        for property in properties {
            if property.name == "powerState" {
                if let value = property.value?.uppercased() {
                    return value == "ON" ? .on : .off
                }
            }
        }
        
        return .unknown
    }
}

/// Power controller directive for turning devices on/off
private struct PowerControllerDirective: Codable {
    let directive: DirectivePayload
    
    init(endpointId: String, action: String) {
        self.directive = DirectivePayload(
            header: DirectiveHeader(
                namespace: "Alexa.PowerController",
                name: action,
                messageId: UUID().uuidString,
                payloadVersion: "3"
            ),
            endpoint: DirectiveEndpoint(endpointId: endpointId),
            payload: [:]
        )
    }
    
    struct DirectivePayload: Codable {
        let header: DirectiveHeader
        let endpoint: DirectiveEndpoint
        let payload: [String: String]
    }
    
    struct DirectiveHeader: Codable {
        let namespace: String
        let name: String
        let messageId: String
        let payloadVersion: String
    }
    
    struct DirectiveEndpoint: Codable {
        let endpointId: String
    }
}

/// API error response structure
private struct APIErrorResponse: Codable {
    let error: String?
    let message: String?
    let code: String?
}
