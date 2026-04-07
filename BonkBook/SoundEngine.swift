import Foundation
import AVFoundation

// Maps slap amplitude → intensity tier, picks a sound file per pack, plays it.
class SoundEngine {

    // MARK: - Intensity tiers

    enum Intensity {
        case whisper    // barely a touch   (amp < 0.05)
        case light      // gentle tap       (0.05 – 0.12)
        case medium     // solid hit        (0.12 – 0.25)
        case heavy      // hard slap        (0.25 – 0.50)
        case brutal     // full send        (>= 0.50)

        init(amplitude: Double) {
            switch amplitude {
            case ..<0.05:  self = .whisper
            case ..<0.12:  self = .light
            case ..<0.25:  self = .medium
            case ..<0.50:  self = .heavy
            default:       self = .brutal
            }
        }
    }

    // MARK: - Sound maps per pack

    /// Returns candidate filenames (without extension) for a given pack + intensity.
    /// Heavier tiers also include files from lighter tiers as fallback.
    static func candidates(pack: SoundMode, intensity: Intensity) -> [String] {
        switch pack {
        case .pain:   return painSounds(intensity)
        case .sexy:   return sexySounds(intensity)
        case .halo:   return haloSounds(intensity)
        default:      return []
        }
    }

    // MARK: Pain

    //  whisper → excuse-me, what-was-that, why         (confused, mild)
    //  light   → ouch, ow                               (simple pain)
    //  medium  → hey-stop, rude, seriously, that-hurt   (protest)
    //  heavy   → not-deserve, slap-impact               (indignant)
    //  brutal  → smack                                  (maximum impact)
    private static func painSounds(_ i: Intensity) -> [String] {
        switch i {
        case .whisper: return ["excuse-me", "what-was-that", "why"]
        case .light:   return ["ouch", "ow"]
        case .medium:  return ["hey-stop", "rude", "seriously", "that-hurt"]
        case .heavy:   return ["not-deserve", "slap-impact"]
        case .brutal:  return ["smack", "slap-impact", "that-hurt"]
        }
    }

    // MARK: Sexy

    //  whisper → ooh                                    (barely a touch)
    //  light   → oh-my, again                           (notice it)
    //  medium  → i-like-that, more, oh-yes              (into it)
    //  heavy   → do-it-again, wow                       (loving it)
    //  brutal  → harder, dont-stop                      (full escalation)
    private static func sexySounds(_ i: Intensity) -> [String] {
        switch i {
        case .whisper: return ["ooh"]
        case .light:   return ["oh-my", "again"]
        case .medium:  return ["i-like-that", "more", "oh-yes"]
        case .heavy:   return ["do-it-again", "wow"]
        case .brutal:  return ["harder", "dont-stop"]
        }
    }

    // MARK: Halo

    //  whisper → notification                           (ping)
    //  light   → hit, hit-sfx                           (basic damage)
    //  medium  → shield-down, taking-damage             (under fire)
    //  heavy   → headshot, critical-hit, killstreak     (kills)
    //  brutal  → double-kill, fatality, unstoppable, game-over (rampage)
    private static func haloSounds(_ i: Intensity) -> [String] {
        switch i {
        case .whisper: return ["notification"]
        case .light:   return ["hit", "hit-sfx"]
        case .medium:  return ["shield-down", "taking-damage"]
        case .heavy:   return ["headshot", "critical-hit", "killstreak"]
        case .brutal:  return ["double-kill", "fatality", "unstoppable", "game-over"]
        }
    }

    // MARK: - Playback

    // Keep all active players alive until they finish
    private var activePlayers: [AVAudioPlayer] = []
    private var lastPlayed: String = ""
    private let lock = NSLock()

    func play(pack: SoundMode, amplitude: Double, soundsBaseURL: URL?) {
        // Audio is handled by spank directly; nothing to do here
        return
        guard let base = soundsBaseURL else { return }

        let intensity = Intensity(amplitude: amplitude)
        var candidates = Self.candidates(pack: pack, intensity: intensity)

        // Avoid repeating the same sound back-to-back
        if candidates.count > 1 {
            candidates.removeAll { $0 == lastPlayed }
        }

        guard let name = candidates.randomElement() else { return }
        lastPlayed = name

        let packDir = base.appendingPathComponent("Custom").appendingPathComponent(pack.rawValue)
        guard let fileURL = findFile(name: name, in: packDir) else { return }

        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self else { return }
            guard let p = try? AVAudioPlayer(contentsOf: fileURL) else { return }
            p.prepareToPlay()
            // Volume scales with amplitude (0.4 floor so whisper is still audible)
            p.volume = Float(min(1.0, max(0.4, amplitude * 2.5)))

            self.lock.lock()
            self.activePlayers.append(p)
            self.lock.unlock()

            p.play()

            // Release after sound duration + small buffer
            let duration = p.duration + 0.2
            DispatchQueue.global().asyncAfter(deadline: .now() + duration) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                self.activePlayers.removeAll { $0 === p }
                self.lock.unlock()
            }
        }
    }

    private func findFile(name: String, in dir: URL) -> URL? {
        let exts = ["m4a", "mp3", "wav", "aiff"]
        for ext in exts {
            let url = dir.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}
