import AppKit
import SwiftUI
import Combine

class MenuBarManager {
    let spankManager: SpankManager
    private let settings: AppSettings
    private let lidSoundManager: LidSoundManager

    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    init() {
        spankManager = SpankManager()
        settings = AppSettings()
        lidSoundManager = LidSoundManager()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        setupStatusItem()
        setupPopover()
        setupBindings()

        spankManager.checkSudoSetup()
        if spankManager.isSudoSetup {
            spankManager.start()
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "BonkBook")
        button.image?.isTemplate = true
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Popover

    private func setupPopover() {
        popover.behavior = .applicationDefined
        popover.animates = true
        let view = PopoverView(spankManager: spankManager, settings: settings)
        popover.contentViewController = NSHostingController(rootView: view)
    }

    // MARK: - Bindings

    private func setupBindings() {
        // Update count badge and flash icon on each slap
        spankManager.onSlap = { [weak self] event in
            self?.updateStatusItemTitle(count: event.slapNumber)
            self?.flashStatusItem()
        }

        // Forward lid sound enabled state to manager
        settings.$lidSoundsEnabled
            .sink { [weak self] enabled in
                self?.lidSoundManager.isEnabled = enabled
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemTitle(count: Int) {
        statusItem.button?.title = count > 0 ? " \(count)" : ""
    }

    private func flashStatusItem() {
        guard let button = statusItem.button else { return }
        button.highlight(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            button.highlight(false)
        }
    }
}
