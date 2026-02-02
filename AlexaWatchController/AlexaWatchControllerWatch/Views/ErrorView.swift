//
//  ErrorView.swift
//  AlexaWatchControllerWatch
//
//  View for displaying error messages with actionable guidance.
//  Validates: Requirements 7.1, 7.4
//

import SwiftUI

/// View for displaying error messages with actionable guidance.
///
/// Requirements:
/// - 7.1: Display connectivity error message
/// - 7.4: Error messages contain actionable guidance
struct ErrorView: View {
    let error: AppError
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    init(
        error: AppError,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Error icon
            Image(systemName: errorIcon)
                .font(.system(size: 40))
                .foregroundColor(errorColor)
            
            // Error title
            Text(errorTitle)
                .font(.headline)
            
            // Error description with guidance
            // Validates: Requirement 7.4 - Error messages contain actionable guidance
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Action buttons
            actionButtons
        }
        .padding()
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if let onRetry = onRetry {
                Button(action: onRetry) {
                    Label("重试", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    Text("关闭")
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var errorIcon: String {
        switch error {
        case .networkUnavailable:
            return "wifi.slash"
        case .authenticationRequired, .tokenExpired:
            return "person.crop.circle.badge.exclamationmark"
        case .apiError:
            return "exclamationmark.icloud"
        case .deviceNotFound:
            return "powerplug.fill"
        case .toggleFailed:
            return "bolt.slash"
        }
    }
    
    private var errorColor: Color {
        switch error {
        case .networkUnavailable:
            return .orange
        case .authenticationRequired, .tokenExpired:
            return .red
        case .apiError:
            return .red
        case .deviceNotFound:
            return .yellow
        case .toggleFailed:
            return .red
        }
    }
    
    private var errorTitle: String {
        switch error {
        case .networkUnavailable:
            return "网络错误"
        case .authenticationRequired:
            return "需要登录"
        case .tokenExpired:
            return "登录已过期"
        case .apiError:
            return "服务错误"
        case .deviceNotFound:
            return "设备未找到"
        case .toggleFailed:
            return "操作失败"
        }
    }
}

// MARK: - Compact Error View

/// A compact error view for inline display.
struct CompactErrorView: View {
    let error: AppError
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(error.localizedDescription)
                .font(.caption)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Previews

#if DEBUG
struct ErrorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ErrorView(
                error: .networkUnavailable,
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Network Error")
            
            ErrorView(
                error: .authenticationRequired,
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Auth Required")
            
            ErrorView(
                error: .tokenExpired,
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Token Expired")
            
            ErrorView(
                error: .toggleFailed("设备无响应"),
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Toggle Failed")
            
            ErrorView(
                error: .deviceNotFound,
                onRetry: {},
                onDismiss: {}
            )
            .previewDisplayName("Device Not Found")
            
            List {
                CompactErrorView(
                    error: .networkUnavailable,
                    onDismiss: {}
                )
            }
            .previewDisplayName("Compact Error")
        }
    }
}
#endif
