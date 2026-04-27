import Foundation
import CryptoKit
import Network
import AppKit
import Security
@preconcurrency import Dispatch

// MARK: - Token Storage Model

private struct SpotifyTokens: Codable {
    var accessToken: String
    var refreshToken: String
    var expiry: Date
}

// MARK: - SpotifyAuthClient

/// Manages Spotify OAuth PKCE flow for the music queue enrichment feature.
/// Handles browser-based auth, local callback server, Keychain token storage, and auto-refresh.
///
/// Usage: check `isConnected`, call `connect()` to authenticate, call `validToken()` to get a
/// fresh access token before each API call, call `disconnect()` to revoke stored credentials.
@MainActor
@Observable
final class SpotifyAuthClient {

    // MARK: - Observable state

    private(set) var isConnected: Bool = false
    private(set) var isConnecting: Bool = false
    private(set) var connectionError: String? = nil

    // MARK: - Private

    private var tokens: SpotifyTokens? {
        didSet { isConnected = tokens != nil }
    }
    /// Guards against concurrent token refreshes — only one refresh runs at a time.
    private var refreshTask: Task<String, Error>?

    // MARK: - Init (nonisolated so it can be stored as a property on nonisolated @Observable owners)

    nonisolated init() {}

    // MARK: - Lifecycle

    /// Loads any previously stored tokens from the Keychain on first access.
    func loadStoredTokens() {
        tokens = KeychainStore.load()
    }

    // MARK: - Connect / Disconnect

    /// Starts the PKCE OAuth flow: opens Spotify in the browser, waits for the callback, exchanges
    /// the code for tokens, and saves them to the Keychain.
    func connect() async {
        guard !SpotifyConfig.clientID.isEmpty else {
            connectionError = "Spotify client ID is not configured. Set SpotifyConfig.clientID."
            return
        }
        guard !isConnecting else { return }
        isConnecting = true
        connectionError = nil

        do {
            let (verifier, challenge) = try PKCE.generatePair()
            let authURL = buildAuthURL(challenge: challenge)
            NSWorkspace.shared.open(authURL)
            let code = try await CallbackServer.waitForCode(on: 8080)
            let newTokens = try await exchangeCode(code, verifier: verifier)
            tokens = newTokens
            KeychainStore.save(newTokens)
        } catch {
            connectionError = error.localizedDescription
        }
        isConnecting = false
    }

    func disconnect() {
        tokens = nil
        refreshTask?.cancel()
        refreshTask = nil
        connectionError = nil
        KeychainStore.delete()
    }

    // MARK: - Token Access

    /// Returns a valid access token, refreshing if the current one is within 60s of expiry.
    /// Serializes concurrent calls so only one refresh occurs at a time.
    func validToken() async throws -> String {
        guard var t = tokens else { throw SpotifyAuthError.notConnected }

        // Already valid — return immediately
        if t.expiry.timeIntervalSinceNow > 60 { return t.accessToken }

        // Coalesce concurrent refresh calls
        if let existing = refreshTask {
            return try await existing.value
        }
        let task = Task<String, Error> { [weak self] in
            guard let self else { throw SpotifyAuthError.notConnected }
            t = try await self.refreshTokens(refreshToken: t.refreshToken)
            self.tokens = t
            KeychainStore.save(t)
            self.refreshTask = nil
            return t.accessToken
        }
        refreshTask = task
        return try await task.value
    }

    // MARK: - Private helpers

    private func buildAuthURL(challenge: String) -> URL {
        var comps = URLComponents(string: SpotifyConfig.authEndpointBase)!
        comps.queryItems = [
            .init(name: "response_type",         value: "code"),
            .init(name: "client_id",              value: SpotifyConfig.clientID),
            .init(name: "scope",                  value: SpotifyConfig.scopes),
            .init(name: "redirect_uri",           value: SpotifyConfig.redirectURI),
            .init(name: "code_challenge_method",  value: "S256"),
            .init(name: "code_challenge",         value: challenge),
        ]
        return comps.url!
    }

    private func exchangeCode(_ code: String, verifier: String) async throws -> SpotifyTokens {
        var req = URLRequest(url: SpotifyConfig.tokenEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params: [String: String] = [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  SpotifyConfig.redirectURI,
            "client_id":     SpotifyConfig.clientID,
            "code_verifier": verifier,
        ]
        req.httpBody = encodeForm(params)
        return try await parseTokenResponse(URLSession.shared.data(for: req))
    }

    private func refreshTokens(refreshToken: String) async throws -> SpotifyTokens {
        var req = URLRequest(url: SpotifyConfig.tokenEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let params: [String: String] = [
            "grant_type":    "refresh_token",
            "refresh_token": refreshToken,
            "client_id":     SpotifyConfig.clientID,
        ]
        req.httpBody = encodeForm(params)
        return try await parseTokenResponse(URLSession.shared.data(for: req))
    }

    private func parseTokenResponse(_ result: (Data, URLResponse)) throws -> SpotifyTokens {
        let (data, resp) = result
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 { throw SpotifyAuthError.unauthorized }
        if !(200..<300).contains(code) { throw SpotifyAuthError.httpError(code) }
        struct R: Decodable {
            let access_token:  String
            let refresh_token: String?
            let expires_in:    Int
        }
        let r = try JSONDecoder().decode(R.self, from: data)
        return SpotifyTokens(
            accessToken:  r.access_token,
            refreshToken: r.refresh_token ?? tokens?.refreshToken ?? "",
            expiry: Date().addingTimeInterval(Double(r.expires_in))
        )
    }

    private func encodeForm(_ params: [String: String]) -> Data {
        params.map { k, v in
            let ek = k.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? k
            let ev = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
            return "\(ek)=\(ev)"
        }
        .joined(separator: "&")
        .data(using: .utf8)!
    }
}

// MARK: - PKCE

private enum PKCE {
    static func generatePair() throws -> (verifier: String, challenge: String) {
        var buf = [UInt8](repeating: 0, count: 64)
        let status = SecRandomCopyBytes(kSecRandomDefault, buf.count, &buf)
        guard status == errSecSuccess else { throw SpotifyAuthError.pkceGenerationFailed }
        let verifier = Data(buf).base64URLEncoded()
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64URLEncoded()
        return (verifier, challenge)
    }
}

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Callback Server

/// A one-shot HTTP listener on 127.0.0.1:<port> that waits for the Spotify redirect
/// and extracts the `code` query parameter. Times out after 5 minutes.
private enum CallbackServer {

    static func waitForCode(on port: UInt16) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host("127.0.0.1"),
                port: NWEndpoint.Port(rawValue: port)!
            )
            let listener: NWListener
            do { listener = try NWListener(using: params) } catch {
                cont.resume(throwing: SpotifyAuthError.listenerFailed(error.localizedDescription))
                return
            }

            // Guards against double-resume if multiple connections arrive.
            let resumeGate = CallbackResumeGate(continuation: cont, listener: listener)

            // Timeout after 5 minutes
            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { return }
                resumeGate.resume(throwing: SpotifyAuthError.authTimeout)
            }
            resumeGate.setTimeoutTask(timeoutTask)

            listener.stateUpdateHandler = { state in
                if case .failed(let err) = state {
                    resumeGate.resume(throwing: SpotifyAuthError.listenerFailed(err.localizedDescription))
                }
            }

            listener.newConnectionHandler = { conn in
                conn.start(queue: .main)
                conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, _ in
                    guard let data,
                          let raw = String(data: data, encoding: .utf8),
                          let code = extractCode(from: raw) else {
                        resumeGate.resume(throwing: SpotifyAuthError.missingCode)
                        sendResponse(to: conn, success: false)
                        return
                    }
                    sendResponse(to: conn, success: true)
                    resumeGate.resume(returning: code)
                }
            }

            listener.start(queue: .main)
        }
    }

    private static func extractCode(from rawHTTP: String) -> String? {
        // First line: "GET /callback?code=…&state=… HTTP/1.1"
        guard let firstLine = rawHTTP.components(separatedBy: "\r\n").first,
              let urlPart = firstLine.components(separatedBy: " ").dropFirst().first,
              let comps = URLComponents(string: "http://x\(urlPart)"),
              let code = comps.queryItems?.first(where: { $0.name == "code" })?.value
        else { return nil }
        return code
    }

    private static func sendResponse(to conn: NWConnection, success: Bool) {
        let body = success
            ? "<h2>Connected to Spotify ✓</h2><p>You can close this tab.</p>"
            : "<h2>Connection failed.</h2><p>Please try again in UtilityNotch settings.</p>"
        let html = "<!DOCTYPE html><html><body>\(body)</body></html>"
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
        conn.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in conn.cancel() })
    }
}

private final class CallbackResumeGate: @unchecked Sendable {
    private let continuation: CheckedContinuation<String, Error>
    private let listener: NWListener
    private let lock = NSLock()
    private var didResume = false
    private var timeoutTask: Task<Void, Never>?

    init(continuation: CheckedContinuation<String, Error>, listener: NWListener) {
        self.continuation = continuation
        self.listener = listener
    }

    func setTimeoutTask(_ task: Task<Void, Never>) {
        lock.lock()
        if didResume {
            lock.unlock()
            task.cancel()
            return
        }
        timeoutTask = task
        lock.unlock()
    }

    func resume(returning code: String) {
        finish {
            continuation.resume(returning: code)
        }
    }

    func resume(throwing error: Error) {
        finish {
            continuation.resume(throwing: error)
        }
    }

    private func finish(_ resumeContinuation: () -> Void) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        let task = timeoutTask
        timeoutTask = nil
        lock.unlock()

        task?.cancel()
        listener.cancel()
        resumeContinuation()
    }
}

// MARK: - Keychain

private enum KeychainStore {

    private static let service = "dev.utilitynotch.spotify"
    private static let account = "tokens"

    static func save(_ tokens: SpotifyTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        delete()
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecValueData:        data,
            kSecAttrAccessible:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> SpotifyTokens? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      account,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let tokens = try? JSONDecoder().decode(SpotifyTokens.self, from: data)
        else { return nil }
        return tokens
    }

    static func delete() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum SpotifyAuthError: LocalizedError {
    case notConnected
    case pkceGenerationFailed
    case listenerFailed(String)
    case authTimeout
    case missingCode
    case unauthorized
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .notConnected:              return "Not connected to Spotify."
        case .pkceGenerationFailed:      return "Failed to generate PKCE code verifier."
        case .listenerFailed(let msg):   return "OAuth callback listener failed: \(msg)"
        case .authTimeout:               return "Spotify authentication timed out."
        case .missingCode:               return "No authorization code in OAuth callback."
        case .unauthorized:              return "Spotify access token expired or revoked."
        case .httpError(let code):       return "Spotify token request failed (HTTP \(code))."
        }
    }
}
