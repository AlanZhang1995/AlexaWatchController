//
//  DeviceRowView.swift
//  AlexaWatchControllerWatch
//
//  Row view for displaying a single smart plug device.
//  Validates: Requirements 3.1, 3.2, 4.2
//

import SwiftUI
#if os(watchOS)
import WatchKit
#endif

/// Row view for displaying a single smart plug device.
///
/// Requirements:
/// - 3.1: Toggle device state on tap
/// - 3.2: Display loading indicator during toggle
/// - 4.2: Display device name and state icon
struct DeviceRowView: View {
    let device: SmartPlug
    let isToggling: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: {
            // Validates: Requirement 3.1 - Toggle device state on tap
            onToggle()
            
            // Validates: Requirement 3.5 - Haptic feedback on toggle
            #if os(watchOS)
            WKInterfaceDevice.current().play(.click)
            #endif
        }) {
            HStack {
                // Device state icon
                // Validates: Requirement 4.2 - Display device name and state icon
                stateIcon
                
                // Device name
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.body)
                        .lineLimit(1)
                    
                    Text(stateText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Loading indicator or toggle indicator
                // Validates: Requirement 3.2 - Display loading indicator during toggle
                if isToggling {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
        .opacity(isToggling ? 0.7 : 1.0)
    }
    
    // MARK: - State Icon
    
    @ViewBuilder
    private var stateIcon: some View {
        ZStack {
            Circle()
                .fill(stateColor.opacity(0.2))
                .frame(width: 36, height: 36)
            
            Image(systemName: stateIconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(stateColor)
        }
    }
    
    // MARK: - Computed Properties
    
    private var stateIconName: String {
        switch device.state {
        case .on:
            return "power"
        case .off:
            return "power"
        case .unknown:
            return "questionmark"
        }
    }
    
    private var stateColor: Color {
        switch device.state {
        case .on:
            return .green
        case .off:
            return .gray
        case .unknown:
            return .orange
        }
    }
    
    private var stateText: String {
        switch device.state {
        case .on:
            return "已开启"
        case .off:
            return "已关闭"
        case .unknown:
            return "状态未知"
        }
    }
}

// MARK: - Previews

#if DEBUG
struct DeviceRowView_Previews: PreviewProvider {
    static var previews: some View {
        List {
            DeviceRowView(
                device: SmartPlug(
                    id: "1",
                    name: "客厅灯",
                    state: .on,
                    manufacturer: nil,
                    model: nil,
                    lastUpdated: Date()
                ),
                isToggling: false,
                onToggle: {}
            )
            
            DeviceRowView(
                device: SmartPlug(
                    id: "2",
                    name: "卧室灯",
                    state: .off,
                    manufacturer: nil,
                    model: nil,
                    lastUpdated: Date()
                ),
                isToggling: false,
                onToggle: {}
            )
            
            DeviceRowView(
                device: SmartPlug(
                    id: "3",
                    name: "正在切换的设备",
                    state: .on,
                    manufacturer: nil,
                    model: nil,
                    lastUpdated: Date()
                ),
                isToggling: true,
                onToggle: {}
            )
            
            DeviceRowView(
                device: SmartPlug(
                    id: "4",
                    name: "状态未知设备",
                    state: .unknown,
                    manufacturer: nil,
                    model: nil,
                    lastUpdated: Date()
                ),
                isToggling: false,
                onToggle: {}
            )
        }
    }
}
#endif
