//
//  AuthenticationView.swift
//  AlexaWatchController
//
//  iOS Companion App authentication view for Amazon OAuth login.
//  Validates: Requirements 1.2, 1.6
//

import SwiftUI
import AuthenticationServices

/// iOS Companion App authentication view for Amazon OAuth login.
///
/// Requirements:
/// - 1.2: Display Amazon login button
/// - 1.6: Display error message and allow retry on auth failure
struct AuthenticationView: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // App icon and title
                headerSection
                
                // Login button or status
                if viewModel.isAuthenticated {
                    authenticatedSection
                } else {
                    loginSection
                }
                
                Spacer()
                
                // Footer
                footerSection
            }
            .padding()
            .navigationTitle("Alexa Watch Controller")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onOpenURL { url in
            // Handle OAuth callback URL
            Task {
                await viewModel.handleOAuthCallback(url: url)
            }
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "applewatch")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("控制您的智能插座")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("使用 Amazon 账户登录以在 Apple Watch 上控制 Alexa 智能插座")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Login Section
    
    @ViewBuilder
    private var loginSection: some View {
        VStack(spacing: 16) {
            // Error message if any
            // Validates: Requirement 1.6 - Display error message on auth failure
            if let error = viewModel.error {
                errorBanner(error: error)
            }
            
            // Login button
            // Validates: Requirement 1.2 - Display Amazon login button
            Button(action: {
                Task {
                    await viewModel.login()
                }
            }) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("使用 Amazon 登录")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.isLoading)
            
            if viewModel.isLoading {
                ProgressView("正在连接...")
                    .progressViewStyle(.circular)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Authenticated Section
    
    @ViewBuilder
    private var authenticatedSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("已登录")
                .font(.headline)
            
            Text("您现在可以在 Apple Watch 上控制智能插座了")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Watch connection status
            watchConnectionStatus
            
            // Logout button
            Button(action: {
                viewModel.logout()
            }) {
                Text("退出登录")
                    .foregroundColor(.red)
            }
            .padding(.top, 20)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Watch Connection Status
    
    @ViewBuilder
    private var watchConnectionStatus: some View {
        HStack {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .foregroundColor(.blue)
            Text("已同步到 Apple Watch")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Error Banner
    
    @ViewBuilder
    private func errorBanner(error: AppError) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("登录失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                viewModel.clearError()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Footer Section
    
    @ViewBuilder
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("登录即表示您同意 Amazon 的服务条款")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("您的凭据将安全存储在设备上")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuthenticationView(
                viewModel: MockAuthViewModel(isAuthenticated: false) as! AuthViewModel
            )
            .previewDisplayName("Not Authenticated")
            
            AuthenticationView(
                viewModel: MockAuthViewModel(isAuthenticated: true) as! AuthViewModel
            )
            .previewDisplayName("Authenticated")
            
            AuthenticationView(
                viewModel: MockAuthViewModel(
                    isAuthenticated: false,
                    isLoading: true
                ) as! AuthViewModel
            )
            .previewDisplayName("Loading")
            
            AuthenticationView(
                viewModel: MockAuthViewModel(
                    isAuthenticated: false,
                    error: .networkUnavailable
                ) as! AuthViewModel
            )
            .previewDisplayName("Error")
        }
    }
}
#endif
