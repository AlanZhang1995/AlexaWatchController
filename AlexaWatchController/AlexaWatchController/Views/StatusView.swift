//
//  StatusView.swift
//  AlexaWatchController
//
//  iOS Companion App status view showing authentication and Watch connection status.
//  Validates: Requirements 1.3, 1.4
//

import SwiftUI

/// iOS Companion App status view showing authentication and Watch connection status.
///
/// Requirements:
/// - 1.3: Display current authentication status
/// - 1.4: Display Watch connection status
struct StatusView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var connectivityService = ConnectivityService.shared
    
    var body: some View {
        NavigationStack {
            List {
                // Authentication status section
                authStatusSection
                
                // Watch connection section
                watchConnectionSection
                
                // Account actions section
                accountActionsSection
            }
            .navigationTitle("状态")
        }
    }
    
    // MARK: - Auth Status Section
    
    @ViewBuilder
    private var authStatusSection: some View {
        Section {
            HStack {
                Image(systemName: authViewModel.isAuthenticated ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(authViewModel.isAuthenticated ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amazon 账户")
                        .font(.headline)
                    Text(authViewModel.isAuthenticated ? "已登录" : "未登录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        } header: {
            Text("认证状态")
        } footer: {
            if authViewModel.isAuthenticated {
                Text("您的 Amazon 账户已连接，可以控制 Alexa 智能插座")
            } else {
                Text("请登录您的 Amazon 账户以使用此应用")
            }
        }
    }
    
    // MARK: - Watch Connection Section
    
    @ViewBuilder
    private var watchConnectionSection: some View {
        Section {
            // Watch reachability
            HStack {
                Image(systemName: connectivityService.isReachable ? "applewatch.radiowaves.left.and.right" : "applewatch.slash")
                    .foregroundColor(connectivityService.isReachable ? .blue : .gray)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Watch")
                        .font(.headline)
                    Text(connectivityService.isReachable ? "已连接" : "未连接")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            
            // Token sync status
            if authViewModel.isAuthenticated {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("凭据同步")
                            .font(.subheadline)
                        Text("已同步到 Watch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Manual sync button
                    Button(action: syncTokenToWatch) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                }
            }
        } header: {
            Text("Watch 连接")
        } footer: {
            if connectivityService.isReachable {
                Text("您的 Apple Watch 已连接，登录凭据会自动同步")
            } else {
                Text("请确保您的 Apple Watch 已配对并在附近")
            }
        }
    }
    
    // MARK: - Account Actions Section
    
    @ViewBuilder
    private var accountActionsSection: some View {
        Section {
            if authViewModel.isAuthenticated {
                Button(action: {
                    authViewModel.logout()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                        Text("退出登录")
                            .foregroundColor(.red)
                    }
                }
            } else {
                Button(action: {
                    Task {
                        await authViewModel.login()
                    }
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundColor(.blue)
                        Text("登录 Amazon 账户")
                            .foregroundColor(.blue)
                    }
                }
                .disabled(authViewModel.isLoading)
            }
        } header: {
            Text("账户操作")
        }
    }
    
    // MARK: - Actions
    
    private func syncTokenToWatch() {
        // Re-sync token to Watch
        if let token = AuthService().getStoredToken() {
            connectivityService.sendToken(token)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct StatusView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StatusView(
                authViewModel: MockAuthViewModel(isAuthenticated: true) as! AuthViewModel
            )
            .previewDisplayName("Authenticated")
            
            StatusView(
                authViewModel: MockAuthViewModel(isAuthenticated: false) as! AuthViewModel
            )
            .previewDisplayName("Not Authenticated")
        }
    }
}
#endif
