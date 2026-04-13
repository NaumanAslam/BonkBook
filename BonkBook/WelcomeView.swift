import SwiftUI
import AppKit

// MARK: - Onboarding Window Controller

final class OnboardingWindowController {
    private var window: NSWindow?
    var onDismiss: (() -> Void)?

    static let shared = OnboardingWindowController()
    private init() {}

    /// Returns true if onboarding was shown (caller should defer .accessory policy).
    @discardableResult
    func showIfNeeded() -> Bool {
        show()
        return true
    }

    func show() {
        if window == nil {
            let hosting = NSHostingView(rootView: OnboardingView(onDismiss: { [weak self] in
                self?.close()
            }))

            let win = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isMovableByWindowBackground = true
            win.level = .floating
            win.backgroundColor = .clear
            win.isOpaque = false
            win.hasShadow = true
            win.contentView = hosting
            win.center()
            window = win
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
        NSApp.setActivationPolicy(.accessory)
        onDismiss?()
    }
}

// MARK: - Onboarding View

private let blue     = Color(red: 0.11, green: 0.42, blue: 0.95)
private let blueDark = Color(red: 0.08, green: 0.33, blue: 0.82)

struct OnboardingView: View {
    let onDismiss: () -> Void

    @State private var handOffset: CGFloat = 0
    @State private var ripple = false
    @State private var step: Int = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "hand.raised.fill",
            iconColor: .white,
            tag: "WELCOME",
            tagColor: Color.white.opacity(0.25),
            title: "Meet BonkBook",
            body: "Slap your MacBook and it'll react with sound.\nThe harder the slap — the louder the response.",
            cta: "Show me how"
        ),
        OnboardingStep(
            icon: "menubar.arrow.up.rectangle",
            iconColor: .white,
            tag: "STEP 1",
            tagColor: Color.white.opacity(0.25),
            title: "Find the hand icon",
            body: "Look at the top-right of your screen.\nYou'll see a ✋ in the menu bar — that's BonkBook.",
            cta: "Got it"
        ),
        OnboardingStep(
            icon: "lock.open.fill",
            iconColor: .white,
            tag: "STEP 2",
            tagColor: Color.white.opacity(0.25),
            title: "Grant permission",
            body: "Click the ✋ icon and tap the button to grant\nroot access — needed to read the accelerometer.",
            cta: "Done, let's go!"
        ),
    ]

    var body: some View {
        ZStack {
            // Full background gradient
            LinearGradient(
                colors: [blue, blueDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative circles
            Circle().fill(.white.opacity(0.05)).frame(width: 200).offset(x: 160, y: -120)
            Circle().fill(.white.opacity(0.04)).frame(width: 140).offset(x: -150, y: 130)

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .strokeBorder(.white.opacity(ripple ? 0 : 0.3), lineWidth: 1.5)
                                .frame(width: ripple ? 110 : 72)
                                .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: ripple)
                        )
                        .overlay(
                            Circle()
                                .strokeBorder(.white.opacity(ripple ? 0 : 0.18), lineWidth: 1)
                                .frame(width: ripple ? 145 : 72)
                                .animation(.easeOut(duration: 1.1).delay(0.25).repeatForever(autoreverses: false), value: ripple)
                        )

                    Image(systemName: steps[step].icon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(steps[step].iconColor)
                        .offset(y: handOffset)
                }
                .padding(.bottom, 20)

                // Tag
                Text(steps[step].tag)
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1.5)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(steps[step].tagColor))
                    .padding(.bottom, 10)

                // Title
                Text(steps[step].title)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.bottom, 8)

                // Body
                Text(steps[step].body)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 32)

                Spacer()

                // Progress dots
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Capsule()
                            .fill(.white.opacity(i == step ? 1 : 0.3))
                            .frame(width: i == step ? 20 : 6, height: 6)
                            .animation(.spring(response: 0.3), value: step)
                    }
                }
                .padding(.bottom, 16)

                // CTA button
                Button(action: advance) {
                    Text(steps[step].cta)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 420, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            startAnimations()
        }
    }

    private func advance() {
        if step < steps.count - 1 {
            withAnimation(.easeInOut(duration: 0.25)) {
                step += 1
            }
        } else {
            onDismiss()
        }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
            handOffset = -6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ripple = true
        }
    }
}

// MARK: - Step Model

private struct OnboardingStep {
    let icon: String
    let iconColor: Color
    let tag: String
    let tagColor: Color
    let title: String
    let body: String
    let cta: String
}
