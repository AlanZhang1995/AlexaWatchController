//
//  DeviceViewModel.swift
//  AlexaWatchController
//
//  ViewModel for managing device list and device operations.
//  Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4
//

import Foundation
import Combine

/// ViewModel responsible for managing the smart plug device list and operations.
/// Handles device fetching, toggling, caching, and error recovery.
///
/// Requirements:
/// - 2.1: Fetch device list from Alexa API on app launch
/// - 2.2: Display device list with names and states
/// - 2.3: Display empty state message when no devices
/// - 2.4: Display loading indicator during fetch
/// - 2.5: Support pull-to-refresh
/// - 3.1: Toggle device state on tap
/// - 3.2: Display loading indicator during toggle
/// - 3.3: Update UI immediately on successful toggle
/// - 3.4: Revert to original state on toggle failure
@MainActor
class DeviceViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The list of smart plug devices.
    /// Validates: Requirement 2.2 - Display device list with names and states
    @Published private(set) var devices: [SmartPlug] = []
    
    /// Indicates whether a loading operation is in progress.
    /// Validates: Requirements 2.4, 3.2 - Display loading indicator
    @Published private(set) var isLoading: Bool = false
    
    /// The current error, if any.
    @Published var error: AppError?
    
    /// Indicates whether the displayed data is from cache.
    /// Validates: Requirement 5.3 - Indicate when displaying cached data
    @Published private(set) var isUsingCache: Bool = false
    
    /// Indicates whether the cache is stale (older than 24 hours).
    /// Validates: Requirement 5.4 - Prompt refresh if cache older than 24 hours
    @Published private(set) var isCacheStale: Bool = false
    
    /// Set of device IDs currently being toggled.
    /// Used to show per-device loading indicators.
    @Published private(set) var togglingDeviceIds: Set<String> = []
    
    // MARK: - Dependencies
    
    /// The Alexa service for API operations
    private let alexaService: AlexaServiceProtocol
    
    /// The cache service for local storage
    private let cacheService: CacheServiceProtocol
    
    /// The auth service for token validation
    private let authService: AuthServiceProtocol
    
    // MARK: - Initialization
    
    /// Creates a new DeviceViewModel instance.
    /// - Parameters:
    ///   - alexaService: The Alexa service for API operations
    ///   - cacheService: The cache service for local storage
    ///   - authService: The auth service for token validation
    init(
        alexaService: AlexaServiceProtocol,
        cacheService: CacheServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.alexaService = alexaService
        self.cacheService = cacheService
        self.authService = authService
    }
    
    /// Convenience initializer using default services.
    convenience init() {
        self.init(
            alexaService: AlexaService(),
            cacheService: CacheService.shared,
            authService: AuthService()
        )
    }
    
    // MARK: - Public Methods
    
    /// Loads the device list from the API or cache.
    /// First attempts to fetch from API, falls back to cache on failure.
    ///
    /// Validates: Requirement 2.1 - Fetch device list from Alexa API
    /// Validates: Requirement 5.2 - Display cached data when offline
    func loadDevices() async {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Attempt to fetch from API
            // Validates: Requirement 2.1 - Fetch device list from Alexa API
            let fetchedDevices = try await alexaService.fetchDevices()
            
            // Update state with fresh data
            devices = fetchedDevices
            isUsingCache = false
            isCacheStale = false
            
            // Cache the fresh data
            // Validates: Requirement 5.1 - Cache device list locally after successful fetch
            cacheService.saveDevices(fetchedDevices)
            
        } catch {
            // Handle error and try to load from cache
            // Validates: Requirement 5.2 - Display cached data when offline
            handleFetchError(error)
        }
        
        isLoading = false
    }
    
    /// Toggles the state of a device.
    /// Optimistically updates the UI, then reverts on failure.
    ///
    /// - Parameter device: The device to toggle
    /// Validates: Requirement 3.1 - Toggle device state on tap
    /// Validates: Requirement 3.3 - Update UI immediately on successful toggle
    /// Validates: Requirement 3.4 - Revert to original state on toggle failure
    func toggleDevice(_ device: SmartPlug) async {
        guard !togglingDeviceIds.contains(device.id) else { return }
        
        // Store original state for rollback
        let originalState = device.state
        let newState: DeviceState = originalState == .on ? .off : .on
        
        // Mark device as toggling
        // Validates: Requirement 3.2 - Display loading indicator during toggle
        togglingDeviceIds.insert(device.id)
        
        // Optimistically update UI
        // Validates: Requirement 3.3 - Update UI immediately
        updateDeviceState(deviceId: device.id, newState: newState)
        
        do {
            // Send toggle request to API
            // Validates: Requirement 3.1 - Toggle device state
            let updatedDevice = try await alexaService.toggleDevice(
                deviceId: device.id,
                newState: newState
            )
            
            // Update with confirmed state from API
            updateDevice(updatedDevice)
            
            // Update cache with new state
            cacheService.saveDevices(devices)
            
        } catch {
            // Validates: Requirement 3.4 - Revert to original state on toggle failure
            updateDeviceState(deviceId: device.id, newState: originalState)
            
            // Set error for display
            if let appError = error as? AppError {
                self.error = appError
            } else {
                self.error = .toggleFailed("操作失败，请重试")
            }
        }
        
        // Remove from toggling set
        togglingDeviceIds.remove(device.id)
    }
    
    /// Refreshes the device list from the API.
    /// Called by pull-to-refresh action.
    ///
    /// Validates: Requirement 2.5 - Support pull-to-refresh
    func refresh() async {
        await loadDevices()
    }
    
    /// Clears the current error state.
    func clearError() {
        error = nil
    }
    
    /// Checks if a specific device is currently being toggled.
    /// - Parameter deviceId: The device ID to check
    /// - Returns: true if the device is being toggled
    func isDeviceToggling(_ deviceId: String) -> Bool {
        togglingDeviceIds.contains(deviceId)
    }
    
    /// Returns whether the device list is empty.
    /// Validates: Requirement 2.3 - Display empty state message when no devices
    var isEmpty: Bool {
        devices.isEmpty && !isLoading
    }
    
    // MARK: - Private Methods
    
    /// Handles a fetch error by loading cached data if available.
    /// - Parameter fetchError: The error that occurred during fetch
    private func handleFetchError(_ fetchError: Error) {
        // Try to load from cache
        if let cachedDevices = cacheService.loadDevices(), !cachedDevices.isEmpty {
            // Validates: Requirement 5.2 - Display cached data when offline
            devices = cachedDevices
            isUsingCache = true
            
            // Validates: Requirement 5.4 - Prompt refresh if cache older than 24 hours
            isCacheStale = cacheService.isCacheStale()
            
            // Set a warning error but still show cached data
            if let appError = fetchError as? AppError {
                error = appError
            } else {
                error = .networkUnavailable
            }
        } else {
            // No cache available, show error
            if let appError = fetchError as? AppError {
                error = appError
            } else {
                error = .networkUnavailable
            }
            devices = []
            isUsingCache = false
            isCacheStale = false
        }
    }
    
    /// Updates the state of a specific device in the list.
    /// - Parameters:
    ///   - deviceId: The ID of the device to update
    ///   - newState: The new state to set
    private func updateDeviceState(deviceId: String, newState: DeviceState) {
        if let index = devices.firstIndex(where: { $0.id == deviceId }) {
            var updatedDevice = devices[index]
            updatedDevice.state = newState
            updatedDevice = SmartPlug(
                id: updatedDevice.id,
                name: updatedDevice.name,
                state: newState,
                manufacturer: updatedDevice.manufacturer,
                model: updatedDevice.model,
                lastUpdated: Date()
            )
            devices[index] = updatedDevice
        }
    }
    
    /// Updates a device in the list with new data.
    /// - Parameter device: The updated device
    private func updateDevice(_ device: SmartPlug) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        }
    }
}

// MARK: - Mock for Testing

#if DEBUG
/// Mock implementation of DeviceViewModel for testing and previews.
@MainActor
class MockDeviceViewModel: ObservableObject {
    @Published var devices: [SmartPlug]
    @Published var isLoading: Bool
    @Published var error: AppError?
    @Published var isUsingCache: Bool
    @Published var isCacheStale: Bool
    @Published var togglingDeviceIds: Set<String>
    
    var isEmpty: Bool {
        devices.isEmpty && !isLoading
    }
    
    init(
        devices: [SmartPlug] = [],
        isLoading: Bool = false,
        error: AppError? = nil,
        isUsingCache: Bool = false,
        isCacheStale: Bool = false,
        togglingDeviceIds: Set<String> = []
    ) {
        self.devices = devices
        self.isLoading = isLoading
        self.error = error
        self.isUsingCache = isUsingCache
        self.isCacheStale = isCacheStale
        self.togglingDeviceIds = togglingDeviceIds
    }
    
    func loadDevices() async {
        isLoading = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoading = false
    }
    
    func toggleDevice(_ device: SmartPlug) async {
        togglingDeviceIds.insert(device.id)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            let newState: DeviceState = devices[index].state == .on ? .off : .on
            devices[index] = SmartPlug(
                id: device.id,
                name: device.name,
                state: newState,
                manufacturer: device.manufacturer,
                model: device.model,
                lastUpdated: Date()
            )
        }
        
        togglingDeviceIds.remove(device.id)
    }
    
    func refresh() async {
        await loadDevices()
    }
    
    func clearError() {
        error = nil
    }
    
    func isDeviceToggling(_ deviceId: String) -> Bool {
        togglingDeviceIds.contains(deviceId)
    }
    
    // MARK: - Preview Helpers
    
    static var preview: MockDeviceViewModel {
        MockDeviceViewModel(
            devices: [
                SmartPlug(id: "1", name: "客厅灯", state: .on, manufacturer: "TP-Link", model: "HS100", lastUpdated: Date()),
                SmartPlug(id: "2", name: "卧室灯", state: .off, manufacturer: "TP-Link", model: "HS100", lastUpdated: Date()),
                SmartPlug(id: "3", name: "书房灯", state: .on, manufacturer: "Meross", model: "MSS110", lastUpdated: Date())
            ]
        )
    }
    
    static var empty: MockDeviceViewModel {
        MockDeviceViewModel(devices: [])
    }
    
    static var loading: MockDeviceViewModel {
        MockDeviceViewModel(isLoading: true)
    }
    
    static var error: MockDeviceViewModel {
        MockDeviceViewModel(error: .networkUnavailable)
    }
    
    static var cached: MockDeviceViewModel {
        MockDeviceViewModel(
            devices: [
                SmartPlug(id: "1", name: "客厅灯", state: .on, manufacturer: nil, model: nil, lastUpdated: Date().addingTimeInterval(-90000))
            ],
            isUsingCache: true,
            isCacheStale: true
        )
    }
}
#endif
