# Recommendation: Music Integration Architecture for Utility Notch

This document recommends the architecture for integrating **Apple Music** and **Spotify** into **Utility Notch**.

It is written for a coding AI agent and assumes the architectural rules in `ARCHITECTURE_RULES.md` are non-negotiable.

---

## 1. Executive recommendation

### Apple Music
Use **MusicKit** as the primary integration layer.

- Use **`SystemMusicPlayer`** when the goal is to mirror/control the user's real Apple Music playback.
- Use the **Apple Music API** only as a **catalog/library enrichment layer**, not as the main playback-control layer.
- Use **`NSWorkspace`** to open the native Music app.

### Spotify
Use the **full Spotify Web API player integration** for a non-commercial app.

- Implement **play/pause/next/previous** through Spotify Player APIs.
- Implement **current track metadata** and **queue preview** through Spotify Web API.
- Open the native Spotify app when needed for deeper playback context.
- Keep the Spotify provider architecture isolated so it can be policy-gated later if the product ever becomes commercial.

### Product-level recommendation
Implement a **shared music abstraction** with:

- `AppleMusicProvider` = full provider
- `SpotifyProvider` = full provider
- `NowPlayingFallbackProvider` = optional generic fallback later

This preserves one shell, one state system, and one module surface across providers.

---

## 2. Non-negotiable product constraints from Utility Notch architecture

The music integration must obey these rules:

1. **One app, one architecture**
   - Dynamic Island and Extended Panel are presentation modes only.
   - They must not fork provider logic, player state, actions, or data models.

2. **Modules do not own layout**
   - The Music module provides content only.
   - It must not create a custom shell, player frame, or provider-specific layout root.

3. **Single source of truth**
   - Playback state, active provider, queue previews, connection state, permissions state, and errors must live in shared app state.

4. **Shared shell**
   - The music integration must render into the existing header/content/footer contract.
   - The canonical shell, sidebar, footer, and transitions remain owned by the shell system.

5. **Mode-independent behavior**
   - Switching between Dynamic Island and Extended Panel must not recreate provider sessions or reset music state.

---

## 3. Correct architecture shape

Use a provider-based architecture.

### Core idea
The app should never talk directly to Apple Music or Spotify from the UI layer.

Instead:

- UI -> `MusicModuleViewModel`
- ViewModel -> `MusicOrchestrator`
- Orchestrator -> `MusicProvider` implementations

This keeps:

- shell shared
- module behavior shared
- provider-specific code isolated
- future providers possible

---

## 4. Recommended layers

## 4.1 Domain layer

Create provider-agnostic models.

```swift
struct TrackCard: Equatable, Identifiable {
    let id: String
    let provider: MusicProviderKind
    let title: String
    let artist: String
    let album: String?
    let artworkURL: URL?
    let deepLinkURL: URL?
}

struct NowPlayingState: Equatable {
    let provider: MusicProviderKind
    let isAvailable: Bool
    let isPlaying: Bool
    let progressSeconds: Double?
    let durationSeconds: Double?
    let current: TrackCard?
    let previous: TrackCard?
    let next: TrackCard?
    let upNext: [TrackCard]
    let playbackSourceLabel: String?
}

struct MusicProviderStatus: Equatable {
    let isAuthorized: Bool
    let isInstalled: Bool
    let hasActiveSession: Bool
    let displayName: String
    let detail: String?
}

enum MusicProviderKind: String, Codable {
    case appleMusic
    case spotify
}
```

Rules:

- `TrackCard` must be provider-agnostic.
- UI must not know about Apple Music `Song` or Spotify JSON types.
- Queue preview data must be normalized before reaching the module UI.

---

## 4.2 Provider protocol

```swift
protocol MusicProvider: AnyObject {
    var kind: MusicProviderKind { get }

    func connect() async
    func disconnect() async
    func refreshStatus() async -> MusicProviderStatus
    func refreshNowPlaying() async -> NowPlayingState

    func playPause() async
    func next() async
    func previous() async
    func openNativeApp()
}
```

Optional extension for richer providers:

```swift
protocol QueueAwareMusicProvider: MusicProvider {
    func refreshQueue() async -> [TrackCard]
}
```

Rules:

- Providers expose capabilities, not raw SDK objects.
- Provider methods must be idempotent where possible.
- Errors must be converted into app-level error states.

---

## 4.3 Orchestration layer

Create `MusicOrchestrator` as the single coordinator.

Responsibilities:

- chooses active provider
- holds cached `NowPlayingState`
- merges polling / observers / notifications into one stream
- exposes simple actions to the module
- de-duplicates refresh work
- prevents provider-specific state from leaking into UI

```swift
@MainActor
final class MusicOrchestrator: ObservableObject {
    @Published private(set) var activeProvider: MusicProviderKind?
    @Published private(set) var providerStatuses: [MusicProviderKind: MusicProviderStatus] = [:]
    @Published private(set) var nowPlaying: NowPlayingState?

    func bootstrap() async
    func refreshAll() async
    func setPreferredProvider(_ kind: MusicProviderKind) async
    func playPause() async
    func next() async
    func previous() async
    func openCurrentProviderApp()
}
```

Rules:

- The orchestrator is the only object the Music module talks to.
- The orchestrator lives in shared app state or shared services.
- The module should never manually instantiate providers.

---

## 5. Apple Music recommendation

## 5.1 Correct Apple stack

Use:

- **MusicKit** for playback integration
- **`SystemMusicPlayer`** for controlling/mirroring system Apple Music playback
- **Apple Music API** only when extra catalog/library data is needed
- **`NSWorkspace`** to open Music.app

### Why this is the correct stack

The Apple Music API is primarily a data API for Apple Music catalog/library resources.
It is not the ideal primary layer for live playback controls in a native macOS music widget.
For the actual player experience, MusicKit is the right primary integration.

---

## 5.2 Apple provider shape

```swift
@MainActor
final class AppleMusicProvider: MusicProvider {
    let kind: MusicProviderKind = .appleMusic

    private let player = SystemMusicPlayer.shared
    private var lastState: NowPlayingState?
    private var shadowQueue: [TrackCard] = []
    private var previousTrack: TrackCard?

    func connect() async
    func disconnect() async
    func refreshStatus() async -> MusicProviderStatus
    func refreshNowPlaying() async -> NowPlayingState

    func playPause() async
    func next() async
    func previous() async
    func openNativeApp()
}
```

---

## 5.3 Apple capability mapping

### Needed feature -> recommended source

- play / pause -> `SystemMusicPlayer`
- next -> `SystemMusicPlayer`
- previous -> `SystemMusicPlayer`
- current title / artist / album -> MusicKit current entry item
- current artwork -> MusicKit artwork URL
- open Music player -> `NSWorkspace`
- next preview card -> local shadow queue
- previous preview card -> cached last seen track

### Important design note

Do **not** rely on the system player alone to always give perfect surrounding queue previews for UI cards.
Instead:

- store the last seen `current` track as `previous`
- maintain a **shadow queue** for `next` and `upNext`
- update shadow state whenever playback advances or the queue changes

This gives a more stable UI than trying to infer everything live from the system every frame.

---

## 5.4 Apple authorization and lifecycle

Recommended startup flow:

1. Check Music authorization.
2. If authorized, connect provider.
3. Subscribe to player state changes.
4. Build normalized `NowPlayingState`.
5. Publish to `MusicOrchestrator`.

Rules:

- Missing permission must be surfaced as provider status, not as a broken module.
- The Music module should show a normal empty/permission state inside the shared shell.
- Authorization logic must not create alternate module layouts.

---

## 5.5 Apple artwork handling

Rules:

- Resolve artwork to URL once.
- Cache image loads through the app's existing image pipeline.
- Never let artwork loading block playback controls.
- If artwork is missing, render the standard music empty-art placeholder.

---

## 6. Spotify recommendation

## 6.1 Product recommendation first

Because the current plan is to keep the app **non-commercial**, Spotify should be implemented as a **full playback-capable provider** using Spotify Web API.

Meaning:

- playback controls are part of the provider contract
- Spotify should feel feature-complete next to Apple Music
- the architecture should still preserve a future policy gate if the product model changes later

The Spotify provider should therefore support full playback capability from the start.

---

## 6.2 Spotify capability model

Spotify should ship in **full playback mode** for the non-commercial app.

Supported:

- current song title
- current artist
- current album
- current artwork
- current playback state
- play / pause
- next
- previous
- queue preview for next items
- open in Spotify app

Design notes:

- use current playback endpoints for active item and playback state
- use queue endpoint for next-track previews
- maintain a local cached `previousTrack` for previous preview UI
- use deep links or native app launch for app handoff

If the product later becomes commercial, keep a central policy switch that can downgrade Spotify to companion mode without changing the module UI.

## 6.3 Spotify provider shape

```swift
@MainActor
final class SpotifyProvider: MusicProvider {
    let kind: MusicProviderKind = .spotify

    private let authClient: SpotifyAuthClient
    private let api: SpotifyWebAPIClient
    private var lastState: NowPlayingState?
    private var previousTrack: TrackCard?
    private var upNext: [TrackCard] = []

    func connect() async
    func disconnect() async
    func refreshStatus() async -> MusicProviderStatus
    func refreshNowPlaying() async -> NowPlayingState

    func playPause() async
    func next() async
    func previous() async
    func openNativeApp()
}
```

---

## 6.4 Spotify implementation rules

### Authentication
Use OAuth Authorization Code with PKCE.

### Control transport
Use Spotify Web API only behind a dedicated API client wrapper.

### Queue strategy
- current -> current playback endpoint
- next -> queue endpoint
- previous -> local cached last seen track

### Open app strategy
Open the native Spotify app via deep link or application launch.

### Polling
Because Spotify desktop state is remote and API-based, use short-interval polling with jitter and backoff.

Recommended polling approach:

- active + visible module: ~2s
- active + hidden panel: ~5s
- inactive provider: ~10–15s
- exponential backoff on auth or transport errors

---

## 6.5 Spotify policy recommendation

### Current recommendation
Because the current product plan is **non-commercial**, implement Spotify with full playback controls.

Reason:
The current architecture goal is feature parity between Apple Music and Spotify for a non-commercial app build.
At the same time, keep the Spotify integration isolated and switchable in case policy or business goals change later.

### Practical rule for this project
For the current build:

- ship Spotify `play/pause/next/previous`
- ship current playback metadata and queue preview
- use PKCE auth and a dedicated Spotify API client
- keep a configuration gate that can disable Spotify controls later if needed

---

## 7. Cross-provider UX rules

The user must not feel like Apple Music and Spotify are two different modules.

### Required shared UI contract
The Music module always exposes the same content regions:

- header title
- provider selector or provider badge
- primary artwork area
- current track metadata
- control row
- optional queue preview row
- footer metadata text

### Rules

- same shell
- same spacing
- same title placement
- same footer system
- same button positions
- same empty state structure
- same animation behavior on module switch

Provider differences must affect **content availability**, not layout identity.

---

## 8. Capability-aware UI behavior

The UI must react to capabilities, not hardcoded provider assumptions.

Example:

```swift
struct MusicCapabilities {
    let canPlayPause: Bool
    let canSkipNext: Bool
    let canSkipPrevious: Bool
    let canShowQueuePreview: Bool
    let canOpenNativeApp: Bool
}
```

### Rules

- Provider capability differences must never collapse the shell.
- Use disabled controls or subtle unavailable states, not alternate layouts.
- In the current build, Apple Music and Spotify should both expose play/pause/next/previous in the UI.

---

## 9. Persistence

Persist only lightweight user preference and provider state.

Persist:

- preferred provider
- last connected provider
- whether Spotify playback controls are force-disabled by config
- last successful artwork URL cache key
- timestamps for freshness

Do not persist:

- long playback history
- raw provider SDK objects
- temporary auth/session state beyond what the auth layer already manages

---

## 10. Recommended files and ownership

## App / shared
- `AppState.swift`
- `MusicOrchestrator.swift`
- `MusicProvider.swift`
- `MusicModels.swift`
- `MusicCapabilities.swift`

## Apple
- `AppleMusicProvider.swift`
- `AppleMusicMapper.swift`
- `AppleMusicAuthorization.swift`

## Spotify
- `SpotifyProvider.swift`
- `SpotifyWebAPIClient.swift`
- `SpotifyAuthClient.swift`
- `SpotifyMapper.swift`
- `SpotifyPolicyGate.swift`

## UI
- `MusicModuleView.swift`
- `MusicModuleViewModel.swift`
- `TrackCardView.swift`
- `PlaybackControlsView.swift`
- `ProviderBadgeView.swift`

Rule:
UI files must never import provider-specific SDK types directly.

---

## 11. Recommended decision logic

When bootstrapping music state:

1. Refresh Apple status.
2. Refresh Spotify status.
3. Choose provider using this order:
   - user preferred provider if available
   - Apple Music if actively available
   - Spotify if metadata session available
   - else empty state
4. Publish one normalized `NowPlayingState`.

---

## 12. What the AI agent should do

### Implement now

1. Create provider-agnostic music models.
2. Create `MusicProvider` protocol.
3. Create `MusicOrchestrator`.
4. Implement `AppleMusicProvider` first.
5. Implement `SpotifyProvider` with full playback support.
6. Build a capability-aware shared Music module UI.
7. Keep all layout inside the canonical shell system.

### Do not do

- do not build separate Apple and Spotify module layouts
- do not fork Dynamic Island vs Extended Panel music logic
- do not let modules own headers, footers, or shell chrome
- do not directly bind SwiftUI views to Spotify JSON or MusicKit raw types
- do not couple Spotify raw API responses directly to SwiftUI views

---

## 13. Final recommendation

### Best architecture for this app

- **Apple Music**: full integration via **MusicKit + `SystemMusicPlayer`**
- **Spotify**: full integration via **Spotify Web API** with play/pause/next/previous and queue preview for the current non-commercial build
- **Shared app design**: one `MusicOrchestrator`, one normalized `NowPlayingState`, one shell, one Music module UI

This is the architecture that best fits:

- Utility Notch's one-shell design
- multi-provider support
- commercial product constraints
- future extensibility
- policy risk containment

---

## 14. Source references

- Apple Music API docs: https://developer.apple.com/documentation/applemusicapi/
- MusicKit `MusicPlayer`: https://developer.apple.com/documentation/musickit/musicplayer
- MusicKit `MusicPlayer.Queue.currentEntry`: https://developer.apple.com/documentation/musickit/musicplayer/queue/currententry
- MusicKit `Song`: https://developer.apple.com/documentation/musickit/song
- NSWorkspace: https://developer.apple.com/documentation/appkit/nsworkspace
- Spotify Developer Policy: https://developer.spotify.com/policy
- Spotify Compliance Tips: https://developer.spotify.com/compliance-tips
- Spotify Web Playback SDK: https://developer.spotify.com/documentation/web-playback-sdk/tutorials/getting-started
- Spotify Web API Authorization: https://developer.spotify.com/documentation/web-api/concepts/authorization

