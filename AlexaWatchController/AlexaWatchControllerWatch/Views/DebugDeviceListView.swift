//
//  DebugDeviceListView.swift
//  AlexaWatchControllerWatch
//
//  调试视图 - 用于在没有真实 Alexa 账户的情况下测试 UI
//

import SwiftUI

#if DEBUG

// MARK: - Debug Device List View

/// 调试用设备列表视图，使用模拟数据
struct DebugDeviceListView: View {
    @StateObject private var viewModel = DebugWatchDeviceViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                // 调试模式提示
                Section {
                    HStack {
                        Image(systemName: "ladybug")
                            .foregroundColor(.orange)
                        Text("调试模式")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // 设备列表
                ForEach(viewModel.devices) { device in
                    DebugWatchDeviceRow(
                        device: device,
                        isToggling: viewModel.togglingDeviceId == device.id,
                        onToggle: {
                            Task {
                                await viewModel.toggleDevice(device)
                            }
                        }
                    )
                }
            }
            .navigationTitle("智能插座")
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
}

// MARK: - Debug Watch Device Row

struct DebugWatchDeviceRow: View {
    let device: DebugSmartPlug
    let isToggling: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                // 设备图标
                Image(systemName: device.isOn ? "powerplug.fill" : "powerplug")
                    .foregroundColor(device.isOn ? .green : .secondary)
                    .font(.title3)
                
                // 设备名称和状态
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(device.isOn ? "已开启" : "已关闭")
                        .font(.caption2)
                        .foregroundColor(device.isOn ? .green : .secondary)
                }
                
                Spacer()
                
                // 状态指示器
                if isToggling {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                } else {
                    Circle()
                        .fill(device.isOn ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(isToggling)
    }
}

// MARK: - Debug Smart Plug Model

struct DebugSmartPlug: Identifiable {
    let id: String
    let name: String
    var isOn: Bool
}

// MARK: - Debug Watch Device ViewModel

@MainActor
class DebugWatchDeviceViewModel: ObservableObject {
    @Published var devices: [DebugSmartPlug] = []
    @Published var togglingDeviceId: String?
    @Published var isLoading = false
    
    init() {
        // 初始化模拟设备
        devices = [
            DebugSmartPlug(id: "1", name: "客厅台灯", isOn: true),
            DebugSmartPlug(id: "2", name: "卧室夜灯", isOn: false),
            DebugSmartPlug(id: "3", name: "书房风扇", isOn: true),
            DebugSmartPlug(id: "4", name: "厨房咖啡机", isOn: false),
            DebugSmartPlug(id: "5", name: "阳台加湿器", isOn: false),
        ]
    }
    
    func toggleDevice(_ device: DebugSmartPlug) async {
        togglingDeviceId = device.id
        
        // 模拟网络延迟
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index].isOn.toggle()
        }
        
        togglingDeviceId = nil
    }
    
    func refresh() async {
        isLoading = true
        
        // 模拟刷新延迟
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        
        isLoading = false
    }
}

// MARK: - Preview

struct DebugDeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        DebugDeviceListView()
    }
}

#endif
