import SwiftUI
import AppKit

@main
struct BonkBookApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No windows — pure menu bar app
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        cleanUpIfNewBuild()
        menuBarManager = MenuBarManager()

        // Start spank only after onboarding is dismissed — avoids a race
        // condition where spank starts while the app is still in regular mode.
        OnboardingWindowController.shared.onDismiss = { [weak self] in
            if self?.menuBarManager?.spankManager.isSudoSetup == true {
                self?.menuBarManager?.spankManager.start()
            }
        }

        OnboardingWindowController.shared.showIfNeeded()
        // .accessory policy is set inside OnboardingWindowController.close()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarManager?.spankManager.stop()
    }

    /// On first launch of a new build, wipe stale UserDefaults so the user
    /// goes through a clean setup. plays.dat (trial counter) is intentionally kept.
    private func cleanUpIfNewBuild() {
        let key = "lastSeenBuildToken"
        guard UserDefaults.standard.string(forKey: key) != AppConstants.buildToken else { return }
        // New build — reset setup state (but NOT plays.dat or sudoers grant record)
        // sudoersSpankPath is intentionally kept: the sudoers file itself is not
        // wiped by cleanUp, so we keep the record in sync. If the spank binary path
        // changes across builds (e.g. app renamed/moved), the path comparison in
        // checkSudoSetup will naturally return false and trigger re-grant.
        let keep: Set<String> = [key]
        for k in UserDefaults.standard.dictionaryRepresentation().keys where !keep.contains(k) {
            UserDefaults.standard.removeObject(forKey: k)
        }
        UserDefaults.standard.set(AppConstants.buildToken, forKey: key)
    }
}
