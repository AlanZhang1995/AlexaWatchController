//
//  AlexaWatchControllerApp.swift
//  AlexaWatchController
//
//  iOS Companion App for Alexa Watch Controller
//  Validates: Requirements 1.2, 1.3, 1.4
//

import SwiftUI
import WatchConnectivity

@main
struct AlexaWatchControllerApp: App {
    
    // MARK: - Dependencies
    
    /// Connectivity manager for Watch-iPhone communication
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    /// Authentication view model
    @StateObject private var authViewModel: AuthViewModel
    
    // MARK: - Initialization
    
    init() {
        // Initialize services
        // 使用 LWAAuthService 支持 Login with Amazon SSO
        let authService = LWAAuthService()
        let connectivityService = ConnectivityService.shared
        
        // Initialize view model with dependency injection
        let authVM = AuthViewModel(
            authService: authService,
            connectivityService: connectivityService
        )
        
        _authViewModel = StateObject(wrappedValue: authVM)
    }
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            MainTabView(authViewModel: authViewModel)
                .environmentObject(connectivityManager)
                .onOpenURL { url in
                    // Handle OAuth callback URL
                    // Validates: Requirement 1.2 - Handle OAuth callback
                    Task {
                        await authViewModel.handleOAuthCallback(url: url)
                    }
                }
        }
    }
}

// MARK: - Main Tab View

/// Main tab view for the iOS Companion App.
struct MainTabView: View {
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        TabView {
            // Authentication Tab
            AuthenticationView(viewModel: authViewModel)
                .tabItem {
                    Label("登录", systemImage: "person.crop.circle")
                }
            
            // Status Tab
            StatusView(authViewModel: authViewModel)
                .tabItem {
                    Label("状态", systemImage: "info.circle")
                }
            
            #if DEBUG
            // Debug Device List Tab (only in debug builds)
            DebugDeviceListView()
                .tabItem {
                    Label("调试", systemImage: "ladybug.fill")
                }
            #endif
        }
    }
}

// MARK: - Previews

#if DEBUG
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView(
            authViewModel: MockAuthViewModel(isAuthenticated: true) as! AuthViewModel
        )
    }
}
#endif
