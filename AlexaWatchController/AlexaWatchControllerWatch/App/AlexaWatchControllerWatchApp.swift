//
//  AlexaWatchControllerWatchApp.swift
//  AlexaWatchControllerWatch
//
//  watchOS App for Alexa Smart Plug Control
//  Validates: Requirements 1.1, 2.1, 4.1
//

import SwiftUI
import WatchConnectivity

@main
struct AlexaWatchControllerWatchApp: App {
    
    // MARK: - Dependencies
    
    /// Connectivity manager for Watch-iPhone communication
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    /// Authentication view model
    @StateObject private var authViewModel: AuthViewModel
    
    /// Device view model
    @StateObject private var deviceViewModel: DeviceViewModel
    
    #if DEBUG
    /// 调试模式开关
    @AppStorage("debugModeEnabled") private var debugModeEnabled = true
    #endif
    
    // MARK: - Initialization
    
    init() {
        // Initialize services
        let authService = AuthService()
        let connectivityService = ConnectivityService.shared
        let alexaService = AlexaService()
        let cacheService = CacheService.shared
        
        // Initialize view models with dependency injection
        let authVM = AuthViewModel(
            authService: authService,
            connectivityService: connectivityService
        )
        
        let deviceVM = DeviceViewModel(
            alexaService: alexaService,
            cacheService: cacheService,
            authService: authService
        )
        
        _authViewModel = StateObject(wrappedValue: authVM)
        _deviceViewModel = StateObject(wrappedValue: deviceVM)
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if debugModeEnabled {
                // 调试模式：显示模拟设备列表
                DebugDeviceListView()
            } else {
                // 正常模式：需要登录
                mainContentView
            }
            #else
            mainContentView
            #endif
        }
    }
    
    // MARK: - Main Content View
    
    @ViewBuilder
    private var mainContentView: some View {
        DeviceListView(
            viewModel: deviceViewModel,
            authViewModel: authViewModel
        )
        .environmentObject(connectivityManager)
        .onAppear {
            // Check auth status on app launch
            // Validates: Requirement 1.1 - Check authentication on launch
            authViewModel.checkAuthStatus()
        }
    }
}

// MARK: - App Delegate for Complications

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    
    func applicationDidFinishLaunching() {
        // Set up WatchConnectivity
        WatchConnectivityManager.shared.activate()
    }
    
    func applicationDidBecomeActive() {
        // Refresh complications when app becomes active
        ComplicationConfigurationManager.shared.reloadAllComplications()
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let complicationTask as WKApplicationRefreshBackgroundTask:
                // Handle complication refresh
                ComplicationConfigurationManager.shared.reloadAllComplications()
                complicationTask.setTaskCompletedWithSnapshot(false)
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
