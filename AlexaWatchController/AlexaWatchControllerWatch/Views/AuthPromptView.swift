//
//  AuthPromptView.swift
//  AlexaWatchControllerWatch
//
//  View prompting user to authenticate via the iPhone Companion App.
//  Validates: Requirements 1.1, 7.2
//

import SwiftUI

/// View prompting user to authenticate via the iPhone Companion App.
///
/// Requirements:
/// - 1.1: Prompt user to complete authentication via Companion App
/// - 7.2: Redirect to re-authentication if token is invalid
struct AuthPromptView: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            // Title
            Text("需要登录")
                .font(.headline)
            
            // Description
            // Validates: Requirement 1.1 - Prompt user to complete authentication via Companion App
            Text("请在 iPhone 上打开 Alexa Watch Controller 应用完成登录")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Error message if any
            if let error = viewModel.error {
                // Validates: Requirement 7.2 - Show error for invalid token
                Text(error.localizedDescription)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Retry button
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                Button(action: {
                    Task {
                        await viewModel.login()
                    }
                }) {
                    Label("检查登录状态", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .onAppear {
            // Check auth status when view appears
            viewModel.checkAuthStatus()
        }
    }
}

// MARK: - Previews

#if DEBUG
struct AuthPromptView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AuthPromptView(
                viewModel: MockAuthViewModel(
                    isAuthenticated: false,
                    needsCompanionAuth: true
                ) as! AuthViewModel
            )
            .previewDisplayName("Not Authenticated")
            
            AuthPromptView(
                viewModel: MockAuthViewModel(
                    isAuthenticated: false,
                    isLoading: true
                ) as! AuthViewModel
            )
            .previewDisplayName("Loading")
            
            AuthPromptView(
                viewModel: MockAuthViewModel(
                    isAuthenticated: false,
                    error: .tokenExpired
                ) as! AuthViewModel
            )
            .previewDisplayName("Token Expired")
        }
    }
}
#endif
