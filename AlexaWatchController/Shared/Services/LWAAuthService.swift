//
//  LWAAuthService.swift
//  AlexaWatchController
//
//  Login with Amazon 认证服务
//  使用 ASWebAuthenticationSession 实现 OAuth 流程
//

import Foundation
import AuthenticationServices

#if canImport(UIKit)
import UIKit
#endif

/// Login with Amazon 认证服务
/// 使用系统级 ASWebAuthenticationSession 实现单点登录
public final class LWAAuthService: NSObject, AuthServiceProtocol {
    
    // MARK: - Properties
    
    private let keychainService: KeychainService
    private let urlSession: URLSession
    private var webAuthSession: ASWebAuthenticationSession?
    private var currentOAuthState: String?
    
    // MARK: - Initialization
    
    public init(
        keychainService: KeychainService = KeychainService(),
        urlSession: URLSession = .shared
    ) {
        self.keychainService = keychainService
        self.urlSession = urlSession
        super.init()
    }
    
    // MARK: - AuthServiceProtocol
    
    public var isAuthenticated: Bool {
        guard let token = getStoredToken() else { return false }
        return !token.isExpired
    }
    
    /// 使用 ASWebAuthenticationSession 发起 OAuth 登录
    /// 支持 SSO - 如果用户已在 Safari/系统中登录 Amazon，可自动填充
    public func initiateOAuth() async throws {
        guard let authURL = getAuthorizationURL() else {
            throw AppError.authenticationRequired
        }
        
        // 保存 state 用于验证
        if let state = currentOAuthState {
            keychainService.save(state, forKey: KeychainKeys.oauthState)
        }
        
        #if canImport(UIKit) && !os(watchOS)
        // 使用 ASWebAuthenticationSession
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: AppConfiguration.oauthRedirectScheme
            ) { [weak self] callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: AppError.authenticationRequired)
                    } else {
                        continuation.resume(throwing: AppError.apiError(error.localizedDescription))
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AppError.authenticationRequired)
                    return
                }
                
                // 处理回调
                Task {
                    do {
                        _ = try await self?.handleCallback(url: callbackURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            session.prefersEphemeralWebBrowserSession = false // 允许 SSO
            session.presentationContextProvider = self
            
            self.webAuthSession = session
            
            DispatchQueue.main.async {
                session.start()
            }
        }
        #endif
    }
    
    public func getAuthorizationURL() -> URL? {
        let state = UUID().uuidString
        currentOAuthState = state
        
        var components = URLComponents(string: AppConfiguration.oauthAuthorizationURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: AppConfiguration.oauthClientId),
            URLQueryItem(name: "scope", value: "alexa::all"),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: AppConfiguration.oauthRedirectURI),
            URLQueryItem(name: "state", value: state)
        ]
        
        return components?.url
    }
    
    public func handleCallback(url: URL) async throws -> AuthToken {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw AppError.authenticationRequired
        }
        
        let code = queryItems.first(where: { $0.name == "code" })?.value
        let state = queryItems.first(where: { $0.name == "state" })?.value
        let error = queryItems.first(where: { $0.name == "error" })?.value
        
        if let error = error {
            throw AppError.apiError("OAuth error: \(error)")
        }
        
        // 验证 state (CSRF 保护)
        let storedState = keychainService.retrieve(String.self, forKey: KeychainKeys.oauthState)
        if let state = state, state != storedState && state != currentOAuthState {
            throw AppError.authenticationRequired
        }
        
        guard let authCode = code else {
            throw AppError.authenticationRequired
        }
        
        let token = try await exchangeCodeForToken(code: authCode)
        keychainService.save(token, forKey: KeychainKeys.authToken)
        keychainService.delete(forKey: KeychainKeys.oauthState)
        currentOAuthState = nil
        
        return token
    }
    
    public func refreshToken() async throws -> AuthToken {
        guard let currentToken = getStoredToken() else {
            throw AppError.authenticationRequired
        }
        
        guard let tokenURL = URL(string: AppConfiguration.oauthTokenURL) else {
            throw AppError.apiError("Invalid token URL")
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": currentToken.refreshToken,
            "client_id": AppConfiguration.oauthClientId,
            "client_secret": AppConfiguration.oauthClientSecret
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            clearToken()
            throw AppError.tokenExpired
        }
        
        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        let newToken = tokenResponse.toAuthToken()
        keychainService.save(newToken, forKey: KeychainKeys.authToken)
        
        return newToken
    }
    
    public func getStoredToken() -> AuthToken? {
        return keychainService.retrieve(AuthToken.self, forKey: KeychainKeys.authToken)
    }
    
    public func clearToken() {
        keychainService.delete(forKey: KeychainKeys.authToken)
        keychainService.delete(forKey: KeychainKeys.oauthState)
        currentOAuthState = nil
    }
    
    // MARK: - Private
    
    private func exchangeCodeForToken(code: String) async throws -> AuthToken {
        guard let tokenURL = URL(string: AppConfiguration.oauthTokenURL) else {
            throw AppError.apiError("Invalid token URL")
        }
        
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": AppConfiguration.oauthRedirectURI,
            "client_id": AppConfiguration.oauthClientId,
            "client_secret": AppConfiguration.oauthClientSecret
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AppError.apiError("Token exchange failed: \(errorMessage)")
        }
        
        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        return tokenResponse.toAuthToken()
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

#if canImport(UIKit) && !os(watchOS)
extension LWAAuthService: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
#endif

// MARK: - OAuth Token Response

private struct OAuthTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
    
    func toAuthToken() -> AuthToken {
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        return AuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            tokenType: tokenType
        )
    }
}
