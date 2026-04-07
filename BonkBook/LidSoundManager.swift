import AppKit
import AVFoundation

/// Plays sounds when the lid is opened or closed.
/// No root required — uses NSWorkspace screensDidSleep/Wake notifications.
class LidSoundManager {
    var isEnabled: Bool = true

    private var openPlayer: AVAudioPlayer?
    private var closePlayer: AVAudioPlayer?

    init() {
        loadSounds()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.play(closing: true) }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.play(closing: false) }
    }

    // Looks for Sounds/Lid/lid-open.* and lid-close.* in the bundle,
    // falls back to macOS system sounds.
    private func loadSounds() {
        let exts = ["m4a", "mp3", "wav", "aiff"]
        if let url = lidSoundURL(name: "lid-open", extensions: exts) {
            openPlayer = try? AVAudioPlayer(contentsOf: url)
            openPlayer?.prepareToPlay()
        } else if let url = systemSoundURL("Glass") {
            openPlayer = try? AVAudioPlayer(contentsOf: url)
            openPlayer?.prepareToPlay()
        }

        if let url = lidSoundURL(name: "lid-close", extensions: exts) {
            closePlayer = try? AVAudioPlayer(contentsOf: url)
            closePlayer?.prepareToPlay()
        } else if let url = systemSoundURL("Funk") {
            closePlayer = try? AVAudioPlayer(contentsOf: url)
            closePlayer?.prepareToPlay()
        }
    }

    private func lidSoundURL(name: String, extensions: [String]) -> URL? {
        guard let lidDir = Bundle.main.url(forResource: "Sounds", withExtension: nil)?
            .appendingPathComponent("Lid") else { return nil }
        for ext in extensions {
            let url = lidDir.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    private func systemSoundURL(_ name: String) -> URL? {
        let path = "/System/Library/Sounds/\(name).aiff"
        return FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
    }

    private func play(closing: Bool) {
        guard isEnabled else { return }
        let player = closing ? closePlayer : openPlayer
        player?.stop()
        player?.currentTime = 0
        player?.play()
    }
}
