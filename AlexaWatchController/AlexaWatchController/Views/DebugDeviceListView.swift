//
//  DebugDeviceListView.swift
//  AlexaWatchController
//
//  Debug view for testing device list functionality without authentication.
//

import SwiftUI

#if DEBUG

/// Debug view for testing device list and toggle functionality
struct DebugDeviceListView: View {
    @StateObject private var viewModel: DeviceViewModel
    
    init() {
        // Create mock services for debug mode
        let mockAuthService = DebugAuthService()
        let mockAlexaService = DebugAlexaService()
        let mockCacheService = DebugCacheService()
        
        let vm = DeviceViewModel(
            alexaService: mockAlexaService,
            cacheService: mockCacheService,
            authService: mockAuthService
        )
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Debug info section
                Section {
                    HStack {
                        Image(systemName: "ladybug.fill")
                            .foregroundColor(.orange)
                        Text("调试模式")
                            .font(.headline)
                        Spacer()
                        Text("模拟数据")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("调试信息")
                }
                
                // Device list section
                Section {
                    if viewModel.isLoading {
                        HStack {
                            ProgressView()
                            Text("加载中...")
                                .foregroundColor(.secondary)
                        }
                    } else if viewModel.devices.isEmpty {
                        Text("没有找到设备")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.devices) { device in
                            DebugDeviceRow(device: device) {
                                Task {
                                    await viewModel.toggleDevice(device)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("智能插座")
                        Spacer()
                        if viewModel.isUsingCache {
                            Label("缓存", systemImage: "clock.arrow.circlepath")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                } footer: {
                    if let error = viewModel.error {
                        Text("错误: \(error.localizedDescription)")
                            .foregroundColor(.red)
                    }
                }
                
                // Actions section
                Section {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }) {
                        Label("刷新设备列表", systemImage: "arrow.clockwise")
                    }
                    
                    Button(action: {
                        viewModel.clearError()
                    }) {
                        Label("清除错误", systemImage: "xmark.circle")
                    }
                } header: {
                    Text("操作")
                }
            }
            .navigationTitle("设备列表 (调试)")
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadDevices()
            }
        }
    }
}

/// Debug device row view
struct DebugDeviceRow: View {
    let device: SmartPlug
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            // Device icon
            Image(systemName: device.state == .on ? "powerplug.fill" : "powerplug")
                .font(.title2)
                .foregroundColor(device.state == .on ? .green : .gray)
                .frame(width: 40)
            
            // Device info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    Text(device.state == .on ? "开启" : "关闭")
                        .font(.caption)
                        .foregroundColor(device.state == .on ? .green : .secondary)
                    
                    if let manufacturer = device.manufacturer {
                        Text("• \(manufacturer)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Toggle button
            Toggle("", isOn: Binding(
                get: { device.state == .on },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Debug Services

/// Debug auth service that always returns authenticated
class DebugAuthService: AuthServiceProtocol {
    var isAuthenticated: Bool { true }
    
    func getAuthorizationURL() -> URL? {
        URL(string: "https://example.com/auth")
    }
    
    func initiateOAuth() async throws {}
    
    func handleCallback(url: URL) async throws -> AuthToken {
        AuthToken(
            accessToken: "debug_token",
            refreshToken: "debug_refresh",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
    }
    
    func refreshToken() async throws -> AuthToken {
        AuthToken(
            accessToken: "debug_token_refreshed",
            refreshToken: "debug_refresh",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
    }
    
    func getStoredToken() -> AuthToken? {
        AuthToken(
            accessToken: "debug_token",
            refreshToken: "debug_refresh",
            expiresAt: Date().addingTimeInterval(3600),
            tokenType: "Bearer"
        )
    }
    
    func clearToken() {}
}

/// Debug Alexa service with mock devices
class DebugAlexaService: AlexaServiceProtocol {
    private var mockDevices: [SmartPlug] = [
        SmartPlug(
            id: "debug-1",
            name: "客厅台灯",
            state: .on,
            manufacturer: "TP-Link",
            model: "HS100",
            lastUpdated: Date()
        ),
        SmartPlug(
            id: "debug-2",
            name: "卧室夜灯",
            state: .off,
            manufacturer: "TP-Link",
            model: "HS105",
            lastUpdated: Date()
        ),
        SmartPlug(
            id: "debug-3",
            name: "书房风扇",
            state: .on,
            manufacturer: "Amazon",
            model: "Smart Plug",
            lastUpdated: Date()
        ),
        SmartPlug(
            id: "debug-4",
            name: "厨房咖啡机",
            state: .off,
            manufacturer: "Wemo",
            model: "Mini",
            lastUpdated: Date()
        ),
        SmartPlug(
            id: "debug-5",
            name: "阳台灯串",
            state: .on,
            manufacturer: "Kasa",
            model: "EP10",
            lastUpdated: Date()
        )
    ]
    
    func fetchDevices() async throws -> [SmartPlug] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)
        return mockDevices
    }
    
    func toggleDevice(deviceId: String, newState: DeviceState) async throws -> SmartPlug {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000)
        
        guard let index = mockDevices.firstIndex(where: { $0.id == deviceId }) else {
            throw AppError.deviceNotFound
        }
        
        let device = mockDevices[index]
        let updated = SmartPlug(
            id: device.id,
            name: device.name,
            state: newState,
            manufacturer: device.manufacturer,
            model: device.model,
            lastUpdated: Date()
        )
        mockDevices[index] = updated
        return updated
    }
    
    func getDeviceState(deviceId: String) async throws -> DeviceState {
        guard let device = mockDevices.first(where: { $0.id == deviceId }) else {
            throw AppError.deviceNotFound
        }
        return device.state
    }
}

/// Debug cache service
class DebugCacheService: CacheServiceProtocol {
    private var cachedDevices: [SmartPlug]?
    private var cacheDate: Date?
    
    func saveDevices(_ devices: [SmartPlug]) {
        cachedDevices = devices
        cacheDate = Date()
    }
    
    func loadDevices() -> [SmartPlug]? {
        cachedDevices
    }
    
    func getCacheAge() -> TimeInterval? {
        guard let date = cacheDate else { return nil }
        return Date().timeIntervalSince(date)
    }
    
    func clearCache() {
        cachedDevices = nil
        cacheDate = nil
    }
    
    func isCacheStale() -> Bool {
        guard let age = getCacheAge() else { return true }
        return age > 300 // 5 minutes
    }
    
    func getCacheTimestamp() -> Date? {
        cacheDate
    }
    
    func loadCachedDeviceList() -> CachedDeviceList? {
        guard let devices = cachedDevices, let date = cacheDate else { return nil }
        return CachedDeviceList(devices: devices, cachedAt: date)
    }
}

// MARK: - Preview

struct DebugDeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        DebugDeviceListView()
    }
}

#endif
