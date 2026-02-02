//
//  DeviceListView.swift
//  AlexaWatchControllerWatch
//
//  Main view displaying the list of smart plug devices.
//  Validates: Requirements 2.2, 2.3, 2.4, 2.5, 4.1, 4.5, 5.3
//

import SwiftUI

/// Main view displaying the list of smart plug devices on the Watch.
///
/// Requirements:
/// - 2.2: Display device list with names and states
/// - 2.3: Display empty state message when no devices
/// - 2.4: Display loading indicator during fetch
/// - 2.5: Support pull-to-refresh
/// - 4.1: Display device list on app launch
/// - 4.5: Display loading indicator during operations
/// - 5.3: Indicate when displaying cached data
struct DeviceListView: View {
    @StateObject var viewModel: DeviceViewModel
    @StateObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if !authViewModel.isAuthenticated {
                // Show auth prompt if not authenticated
                AuthPromptView(viewModel: authViewModel)
            } else if viewModel.isLoading && viewModel.devices.isEmpty {
                // Validates: Requirement 2.4 - Display loading indicator during fetch
                LoadingView()
            } else if viewModel.isEmpty {
                // Validates: Requirement 2.3 - Display empty state message
                EmptyDeviceView(onRefresh: {
                    Task {
                        await viewModel.refresh()
                    }
                })
            } else {
                // Validates: Requirement 2.2 - Display device list
                deviceListContent
            }
        }
        .task {
            // Validates: Requirement 4.1 - Display device list on app launch
            if authViewModel.isAuthenticated {
                await viewModel.loadDevices()
            }
        }
        .onChange(of: authViewModel.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                Task {
                    await viewModel.loadDevices()
                }
            }
        }
    }
    
    // MARK: - Device List Content
    
    @ViewBuilder
    private var deviceListContent: some View {
        NavigationStack {
            List {
                // Validates: Requirement 5.3 - Indicate when displaying cached data
                if viewModel.isUsingCache {
                    cacheWarningSection
                }
                
                // Device list
                ForEach(viewModel.devices) { device in
                    DeviceRowView(
                        device: device,
                        isToggling: viewModel.isDeviceToggling(device.id),
                        onToggle: {
                            Task {
                                await viewModel.toggleDevice(device)
                            }
                        }
                    )
                }
            }
            .navigationTitle("智能插座")
            // Validates: Requirement 2.5 - Support pull-to-refresh
            .refreshable {
                await viewModel.refresh()
            }
            .overlay {
                // Show error overlay if there's an error
                if let error = viewModel.error, !viewModel.isUsingCache {
                    ErrorOverlayView(
                        error: error,
                        onRetry: {
                            Task {
                                await viewModel.refresh()
                            }
                        },
                        onDismiss: {
                            viewModel.clearError()
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Cache Warning Section
    
    @ViewBuilder
    private var cacheWarningSection: some View {
        Section {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("显示缓存数据")
                        .font(.caption)
                        .foregroundColor(.orange)
                    if viewModel.isCacheStale {
                        Text("数据可能已过期")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Loading View

/// View displayed while loading devices.
/// Validates: Requirement 2.4 - Display loading indicator during fetch
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("加载中...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Empty Device View

/// View displayed when no devices are found.
/// Validates: Requirement 2.3 - Display empty state message when no devices
struct EmptyDeviceView: View {
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "powerplug")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("未找到设备")
                .font(.headline)
            
            Text("请确保您的 Alexa 账户已关联智能插座")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onRefresh) {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Error Overlay View

/// Overlay view for displaying errors.
/// Validates: Requirement 7.1, 7.4 - Display error with guidance
struct ErrorOverlayView: View {
    let error: AppError
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundColor(.red)
            
            Text(error.localizedDescription)
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("重试", action: onRetry)
                    .buttonStyle(.bordered)
                
                Button("关闭", action: onDismiss)
                    .buttonStyle(.bordered)
                    .tint(.secondary)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
    }
}

// MARK: - Previews

#if DEBUG
struct DeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Normal state with devices
            DeviceListView(
                viewModel: MockDeviceViewModel.preview as! DeviceViewModel,
                authViewModel: MockAuthViewModel(isAuthenticated: true) as! AuthViewModel
            )
            .previewDisplayName("With Devices")
            
            // Empty state
            DeviceListView(
                viewModel: MockDeviceViewModel.empty as! DeviceViewModel,
                authViewModel: MockAuthViewModel(isAuthenticated: true) as! AuthViewModel
            )
            .previewDisplayName("Empty")
            
            // Loading state
            DeviceListView(
                viewModel: MockDeviceViewModel.loading as! DeviceViewModel,
                authViewModel: MockAuthViewModel(isAuthenticated: true) as! AuthViewModel
            )
            .previewDisplayName("Loading")
            
            // Cached data
            DeviceListView(
                viewModel: MockDeviceViewModel.cached as! DeviceViewModel,
                authViewModel: MockAuthViewModel(isAuthenticated: true) as! AuthViewModel
            )
            .previewDisplayName("Cached")
        }
    }
}
#endif
