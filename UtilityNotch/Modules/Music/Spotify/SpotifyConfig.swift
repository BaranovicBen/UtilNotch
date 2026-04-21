import Foundation

// MARK: - Spotify OAuth Configuration
// Register your app at https://developer.spotify.com/dashboard and set clientID.
// Set the redirect URI to http://127.0.0.1:8080/callback in your Spotify app settings.
enum SpotifyConfig {
    /// Spotify application client ID. Set this before building.
    static let clientID = "58efd3398efe400eae6ca7a4a64831ca"
    static let redirectURI = "http://127.0.0.1:8080/callback"
    static let scopes = "user-read-playback-state"
    static let tokenEndpoint = URL(string: "https://accounts.spotify.com/api/token")!
    static let authEndpointBase = "https://accounts.spotify.com/authorize"
    static let queueEndpoint = URL(string: "https://api.spotify.com/v1/me/player/queue")!
}
