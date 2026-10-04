public struct AppSettings: Sendable, Equatable, Codable {
    public var hotkeys: HotkeyBindings
    public var interceptsTrackpadSwipes: Bool
    public var showsOverlay: Bool
    public var preventsEmptyDesktopYank: Bool
    public var showsSpaceNumberInMenuBar: Bool

    public init(
        hotkeys: HotkeyBindings,
        interceptsTrackpadSwipes: Bool,
        showsOverlay: Bool,
        preventsEmptyDesktopYank: Bool,
        showsSpaceNumberInMenuBar: Bool
    ) {
        self.hotkeys = hotkeys
        self.interceptsTrackpadSwipes = interceptsTrackpadSwipes
        self.showsOverlay = showsOverlay
        self.preventsEmptyDesktopYank = preventsEmptyDesktopYank
        self.showsSpaceNumberInMenuBar = showsSpaceNumberInMenuBar
    }

    public static let `default` = AppSettings(
        hotkeys: .default,
        interceptsTrackpadSwipes: true,
        showsOverlay: true,
        preventsEmptyDesktopYank: true,
        showsSpaceNumberInMenuBar: true
    )
}
