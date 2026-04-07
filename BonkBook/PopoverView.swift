import SwiftUI
import AppKit

private let blue = Color(red: 0.11, green: 0.42, blue: 0.95)
private let blueDark = Color(red: 0.08, green: 0.33, blue: 0.82)

// MARK: - Root

struct PopoverView: View {
    @ObservedObject var spankManager: SpankManager
    @ObservedObject var settings: AppSettings

    var body: some View {
        if !spankManager.isSudoSetup {
            SetupView(spankManager: spankManager)
        } else {
            MainView(spankManager: spankManager, settings: settings)
        }
    }
}

// MARK: - Main

struct MainView: View {
    @ObservedObject var spankManager: SpankManager
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            HeaderSection(spankManager: spankManager)
            ScrollView {
                VStack(spacing: 12) {
                    StatsCard(spankManager: spankManager)
                    SoundPackCard(spankManager: spankManager)
                    DetectionCard(spankManager: spankManager)
                    SettingsCard(spankManager: spankManager, settings: settings)
                }
                .padding(12)
            }
            FooterSection(spankManager: spankManager)
        }
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Header

struct HeaderSection: View {
    @ObservedObject var spankManager: SpankManager

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [blue, blueDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle decorative circles
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 120, height: 120)
                .offset(x: 110, y: -30)
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 80, height: 80)
                .offset(x: -100, y: 30)

            HStack(spacing: 10) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("BonkBook")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    StatusPill(spankManager: spankManager)
                }

                Spacer()

                // Start/Stop button
                Button {
                    if spankManager.isRunning { spankManager.stop() }
                    else { spankManager.start() }
                } label: {
                    Text(spankManager.isRunning ? "Stop" : "Start")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(.white.opacity(spankManager.isRunning ? 0.2 : 0.15))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .frame(height: 76)
        .clipped()
    }
}

struct StatusPill: View {
    @ObservedObject var spankManager: SpankManager

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .shadow(color: dotColor.opacity(0.8), radius: dotColor == .green ? 3 : 0)
            Text(statusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(.white.opacity(0.12)))
    }

    private var dotColor: Color {
        guard spankManager.isRunning else { return .white.opacity(0.4) }
        return spankManager.isReady ? Color(red: 0.27, green: 0.90, blue: 0.55) : .yellow
    }

    private var statusText: String {
        guard spankManager.isRunning else { return "Stopped" }
        return spankManager.isReady ? "Listening" : "Starting..."
    }
}

// MARK: - Stats Card

struct StatsCard: View {
    @ObservedObject var spankManager: SpankManager
    @State private var bouncing = false

    var body: some View {
        HStack(spacing: 0) {
            // Slap count
            VStack(spacing: 6) {
                Text("\(spankManager.slapCount)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(blue)
                    .contentTransition(.numericText(countsDown: false))
                    .scaleEffect(bouncing ? 1.15 : 1.0)
                    .onChange(of: spankManager.slapCount) { _ in
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) { bouncing = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            withAnimation { bouncing = false }
                        }
                    }
                Label("Total Slaps", systemImage: "hand.tap.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 1, height: 50)

            // Last hit
            VStack(spacing: 6) {
                Text(spankManager.lastSeverity.isEmpty ? "—" : spankManager.lastSeverity.capitalized)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(severityColor)
                Label("Last Hit", systemImage: "waveform")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 16)
        .background(cardBackground)
    }

    private var severityColor: Color {
        switch spankManager.lastSeverity.lowercased() {
        case "light":    return blue
        case "moderate": return .orange
        case "severe":   return .red
        default:         return .secondary
        }
    }
}

// MARK: - Sound Pack Card

struct SoundPackCard: View {
    @ObservedObject var spankManager: SpankManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardLabel(icon: "speaker.wave.2.fill", title: "Sound Pack")

            HStack(spacing: 8) {
                ForEach(SoundMode.allCases) { mode in
                    PackButton(mode: mode, isSelected: spankManager.soundMode == mode) {
                        spankManager.soundMode = mode
                    }
                }
            }
        }
        .padding(14)
        .background(cardBackground)
    }
}

struct PackButton: View {
    let mode: SoundMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isSelected ? blue : blue.opacity(0.08))
                        .frame(width: 34, height: 34)
                    Image(systemName: mode.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isSelected ? .white : blue)
                }
                Text(mode.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? blue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? blue.opacity(0.08) : Color.secondary.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? blue.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Detection Card

struct DetectionCard: View {
    @ObservedObject var spankManager: SpankManager

    private var sensitivityBinding: Binding<Double> {
        Binding(
            get: { 1.0 - (spankManager.sensitivity / 0.5) },
            set: { spankManager.sensitivity = max(0.01, (1.0 - $0) * 0.5) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardLabel(icon: "antenna.radiowaves.left.and.right", title: "Detection")

            VStack(spacing: 10) {
                SliderRow(
                    label: "Sensitivity",
                    value: sensitivityLabel,
                    binding: sensitivityBinding,
                    range: 0...1
                ) {
                    if spankManager.isRunning { spankManager.updateSettings() }
                }

                Divider().opacity(0.5)

                SliderRow(
                    label: "Cooldown",
                    value: "\(spankManager.cooldownMs) ms",
                    binding: Binding(
                        get: { Double(spankManager.cooldownMs) },
                        set: { spankManager.cooldownMs = Int($0) }
                    ),
                    range: 100...2000,
                    step: 50
                ) {
                    if spankManager.isRunning { spankManager.updateSettings() }
                }
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var sensitivityLabel: String {
        switch spankManager.sensitivity {
        case ..<0.02: return "Max"
        case ..<0.05: return "High"
        case ..<0.10: return "Medium"
        case ..<0.20: return "Low"
        default:      return "Min"
        }
    }
}

struct SliderRow: View {
    let label: String
    let value: String
    let binding: Binding<Double>
    let range: ClosedRange<Double>
    var step: Double? = nil
    let onEditingEnd: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(blue)
                    .monospacedDigit()
            }
            if let step {
                Slider(value: binding, in: range, step: step) { editing in
                    if !editing { onEditingEnd() }
                }
                .tint(blue)
            } else {
                Slider(value: binding, in: range) { editing in
                    if !editing { onEditingEnd() }
                }
                .tint(blue)
            }
        }
    }
}

// MARK: - Settings Card

struct SettingsCard: View {
    @ObservedObject var spankManager: SpankManager
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardLabel(icon: "gearshape.fill", title: "Settings")

            HStack {
                Label("Lid open / close sounds", systemImage: "macbook")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                Spacer()
                Toggle("", isOn: $settings.lidSoundsEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(blue)
                    .labelsHidden()
            }
        }
        .padding(14)
        .background(cardBackground)
    }
}

// MARK: - Footer

struct FooterSection: View {
    @ObservedObject var spankManager: SpankManager

    var body: some View {
        HStack {
            Button {
                withAnimation { spankManager.slapCount = 0 }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text("Quit")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.05))
        .overlay(Rectangle().fill(Color.secondary.opacity(0.1)).frame(height: 1), alignment: .top)
    }
}

// MARK: - Shared Helpers

private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 12)
        .fill(Color(NSColor.controlBackgroundColor))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
}

struct CardLabel: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(blue)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - App Settings

class AppSettings: ObservableObject {
    @Published var lidSoundsEnabled: Bool = true {
        didSet { UserDefaults.standard.set(lidSoundsEnabled, forKey: "lidSoundsEnabled") }
    }

    init() {
        lidSoundsEnabled = UserDefaults.standard.object(forKey: "lidSoundsEnabled") as? Bool ?? true
    }
}
