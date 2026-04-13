import Foundation

enum AppConstants {
    /// Flip to `true` before building the paid DMG, `false` for the free trial DMG.
    static let isPremium: Bool = false

    /// How many slap sounds the free tier allows before locking.
    static let freeSlapLimit: Int = 7

    /// Gumroad product URL shown in the upgrade prompt.
    static let gumroadURL = "https://naumantics.gumroad.com/l/euvdwc"

    /// Bump this when shipping a new build. Triggers a clean slate for
    /// setup state on first launch (stale sudoers, etc) while keeping plays.dat.
    static let buildToken = "2026-04-13-v1"
}
