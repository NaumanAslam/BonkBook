import SwiftUI

struct SetupView: View {
    @ObservedObject var spankManager: SpankManager
    @State private var isInstalling = false
    @State private var installError = false

    private let blue = Color(red: 0.11, green: 0.42, blue: 0.95)

    var body: some View {
        VStack(spacing: 0) {
            // Blue header
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.11, green: 0.42, blue: 0.95),
                             Color(red: 0.08, green: 0.33, blue: 0.82)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 52, height: 52)
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text("BonkBook")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.vertical, 24)
            }
            .frame(height: 120)

            // Body
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("One-time setup required")
                        .font(.system(size: 13, weight: .semibold))

                    Text("BonkBook needs permission to run the accelerometer sensor, which requires root access.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if installError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.system(size: 12))
                        Text("Setup failed. Make sure spank is at /usr/local/bin/spank")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    install()
                } label: {
                    Group {
                        if isInstalling {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Installing...")
                            }
                        } else {
                            Label("Grant Permission", systemImage: "lock.open.fill")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isInstalling ? Color.secondary : blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(isInstalling)

                Button("Quit") { NSApp.terminate(nil) }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
            .padding(20)
        }
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func install() {
        guard FileManager.default.fileExists(atPath: SpankManager.spankPath) else {
            installError = true
            return
        }
        isInstalling = true
        installError = false
        spankManager.installSudoersRule { success in
            isInstalling = false
            installError = !success
            if success { spankManager.start() }
        }
    }
}
