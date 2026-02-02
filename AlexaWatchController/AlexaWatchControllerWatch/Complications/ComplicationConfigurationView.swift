//
//  ComplicationConfigurationView.swift
//  AlexaWatchControllerWatch
//
//  View for configuring which device a complication controls.
//  Validates: Requirements 6.5, 6.6
//

import SwiftUI
import ClockKit

/// View for configuring which device a complication controls.
///
/// Requirements:
/// - 6.5: Allow user to select device for complication
/// - 6.6: Save complication configuration
struct ComplicationConfigurationView: View {
    @ObservedObject var deviceViewModel: DeviceViewModel
    @Environment(\.dismiss) private var dismiss
    
    let complicationId: String
    @State private var selectedDeviceId: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if deviceViewModel.isLoading && deviceViewModel.devices.isEmpty {
                    loadingView
                } else if deviceViewModel.devices.isEmpty {
                    emptyView
                } else {
                    deviceSelectionList
                }
            }
            .navigationTitle("选择设备")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveConfiguration()
                        dismiss()
                    }
                    .disabled(selectedDeviceId == nil)
                }
            }
        }
        .task {
            await deviceViewModel.loadDevices()
            loadCurrentConfiguration()
        }
    }
    
    // MARK: - Loading View
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("加载设备列表...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Empty View
    
    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "powerplug")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("未找到设备")
                .font(.headline)
            
            Text("请先在 Alexa 应用中添加智能插座")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("刷新") {
                Task {
                    await deviceViewModel.refresh()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Device Selection List
    
    @ViewBuilder
    private var deviceSelectionList: some View {
        List {
            Section {
                ForEach(deviceViewModel.devices) { device in
                    DeviceSelectionRow(
                        device: device,
                        isSelected: selectedDeviceId == device.id,
                        onSelect: {
                            selectedDeviceId = device.id
                        }
                    )
                }
            } header: {
                Text("选择要控制的设备")
            } footer: {
                Text("选择的设备将显示在表盘上，点击可快速切换状态")
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadCurrentConfiguration() {
        if let config = ComplicationConfigurationManager.shared.getConfiguration(for: complicationId) {
            selectedDeviceId = config.deviceId
        }
    }
    
    /// Saves the complication configuration.
    /// Validates: Requirement 6.6 - Save complication configuration
    private func saveConfiguration() {
        guard let deviceId = selectedDeviceId,
              let device = deviceViewModel.devices.first(where: { $0.id == deviceId }) else {
            return
        }
        
        let configuration = ComplicationConfiguration(
            complicationId: complicationId,
            deviceId: device.id,
            deviceName: device.name,
            deviceState: device.state
        )
        
        ComplicationConfigurationManager.shared.saveConfiguration(configuration, for: complicationId)
    }
}

// MARK: - Device Selection Row

/// Row view for device selection in complication configuration.
struct DeviceSelectionRow: View {
    let device: SmartPlug
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Device icon
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "power")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(stateColor)
                }
                
                // Device info
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.body)
                    Text(stateText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private var stateColor: Color {
        switch device.state {
        case .on: return .green
        case .off: return .gray
        case .unknown: return .orange
        }
    }
    
    private var stateText: String {
        switch device.state {
        case .on: return "已开启"
        case .off: return "已关闭"
        case .unknown: return "状态未知"
        }
    }
}

// MARK: - Complication Intent Handler

/// Handles complication tap actions.
/// Validates: Requirement 6.3 - Handle tap to toggle device
@MainActor
class ComplicationIntentHandler {
    static let shared = ComplicationIntentHandler()
    
    private init() {}
    
    /// Handles a tap on a complication.
    /// Validates: Requirement 6.3 - Handle tap to toggle device
    func handleComplicationTap(complicationId: String, deviceViewModel: DeviceViewModel) async {
        guard let config = ComplicationConfigurationManager.shared.getConfiguration(for: complicationId),
              let device = deviceViewModel.devices.first(where: { $0.id == config.deviceId }) else {
            return
        }
        
        // Toggle the device
        await deviceViewModel.toggleDevice(device)
        
        // Update complication state
        if let updatedDevice = deviceViewModel.devices.first(where: { $0.id == config.deviceId }) {
            ComplicationConfigurationManager.shared.updateDeviceState(
                deviceId: updatedDevice.id,
                newState: updatedDevice.state
            )
        }
    }
}

// MARK: - Previews

#if DEBUG
struct ComplicationConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ComplicationConfigurationView(
            deviceViewModel: MockDeviceViewModel.preview as! DeviceViewModel,
            complicationId: "test_complication"
        )
    }
}
#endif
