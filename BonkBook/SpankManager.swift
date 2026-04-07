import Foundation
import Combine

// JSON event emitted by spank --stdio on each slap
struct SlapEvent: Decodable {
    let timestamp: String
    let slapNumber: Int
    let amplitude: Double
    let severity: String
    let file: String
}

// The three custom packs with bundled sounds
enum SoundMode: String, CaseIterable, Identifiable {
    case pain, sexy, halo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pain: return "Pain"
        case .sexy: return "Sexy"
        case .halo: return "Halo"
        }
    }

    var icon: String {
        switch self {
        case .pain: return "hand.raised.fill"
        case .sexy: return "flame.fill"
        case .halo: return "staroflife.fill"
        }
    }
}

class SpankManager: ObservableObject {
    // State
    @Published var isRunning = false
    @Published var isReady = false
    @Published var slapCount = 0
    @Published var lastAmplitude: Double = 0
    @Published var lastSeverity = ""
    @Published var isSudoSetup = false

    // Settings
    @Published var soundMode: SoundMode = .pain
    @Published var sensitivity: Double = 0.05
    @Published var cooldownMs: Int = 750

    var onSlap: ((SlapEvent) -> Void)?

    private let soundEngine = SoundEngine()
    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stdinPipe: Pipe?
    private var lineBuffer = ""

    static var spankPath: String {
        Bundle.main.url(forAuxiliaryExecutable: "spank")?.path ?? "/usr/local/bin/spank"
    }
    static let sudoersPath = "/etc/sudoers.d/bonkbook"

    var soundsBaseURL: URL? {
        Bundle.main.url(forResource: "Sounds", withExtension: nil)
    }

    var customSoundsURL: URL? {
        soundsBaseURL?.appendingPathComponent("Custom")
    }

    var lidSoundsURL: URL? {
        soundsBaseURL?.appendingPathComponent("Lid")
    }

    // MARK: - Setup

    func checkSudoSetup() {
        isSudoSetup = FileManager.default.fileExists(atPath: Self.sudoersPath)
    }

    func installSudoersRule(completion: @escaping (Bool) -> Void) {
        let sudoersLine = "%admin ALL=(ALL) NOPASSWD: \(Self.spankPath)"
        let shellCmd = "echo '\(sudoersLine)' > \(Self.sudoersPath) && chmod 440 \(Self.sudoersPath)"
        let script = "do shell script \"\(shellCmd)\" with administrator privileges"

        DispatchQueue.global().async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            DispatchQueue.main.async {
                let success = error == nil && FileManager.default.fileExists(atPath: Self.sudoersPath)
                self.isSudoSetup = success
                completion(success)
            }
        }
    }

    // MARK: - Process lifecycle

    func start() {
        guard !isRunning else { return }
        guard FileManager.default.fileExists(atPath: Self.spankPath) else { return }

        let proc = Process()
        let stdout = Pipe()
        let stdin = Pipe()

        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")

        // Use --stdio: spank handles audio, Swift handles UI
        let args: [String] = [
            Self.spankPath,
            "--stdio",
            "--min-amplitude", String(format: "%.3f", sensitivity),
            "--cooldown", String(cooldownMs)
        ]

        proc.arguments = args
        proc.standardOutput = stdout
        proc.standardInput = stdin
        proc.standardError = FileHandle.nullDevice

        self.process = proc
        self.stdoutPipe = stdout
        self.stdinPipe = stdin

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.handleOutput(data)
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.isReady = false
                self?.stdoutPipe?.fileHandleForReading.readabilityHandler = nil
            }
        }

        do {
            try proc.run()
            DispatchQueue.main.async { self.isRunning = true }
        } catch {
            print("Failed to launch spank: \(error)")
        }
    }

    func stop() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
        stdoutPipe = nil
        stdinPipe = nil
        lineBuffer = ""
        DispatchQueue.main.async {
            self.isRunning = false
            self.isReady = false
        }
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.start() }
    }

    // MARK: - Stdin commands

    func sendCommand(_ dict: [String: Any]) {
        guard let pipe = stdinPipe,
              let data = try? JSONSerialization.data(withJSONObject: dict),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        pipe.fileHandleForWriting.write(Data(line.utf8))
    }

    func updateSettings() {
        sendCommand(["cmd": "set", "amplitude": sensitivity, "cooldown": cooldownMs])
    }



    // MARK: - Output parsing

    private func handleOutput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        lineBuffer += text
        let lines = lineBuffer.components(separatedBy: "\n")
        lineBuffer = lines.last ?? ""

        for line in lines.dropLast() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, trimmed.hasPrefix("{") else { continue }
            guard let jsonData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            else { continue }

            if let status = json["status"] as? String, status == "ready" {
                DispatchQueue.main.async { self.isReady = true }
            } else if json["slapNumber"] != nil,
                      let event = try? JSONDecoder().decode(SlapEvent.self, from: jsonData) {
                DispatchQueue.main.async {
                    self.slapCount = event.slapNumber
                    self.lastAmplitude = event.amplitude
                    self.lastSeverity = event.severity
                    self.onSlap?(event)
                }
                // Play sound immediately on the detection thread (don't wait for main)
                self.soundEngine.play(
                    pack: self.soundMode,
                    amplitude: event.amplitude,
                    soundsBaseURL: self.soundsBaseURL
                )
            }
        }
    }
}
