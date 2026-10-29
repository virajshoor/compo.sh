import AppKit
import SwiftUI
import CompoCore
import ServiceManagement

@main
enum CompoApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let manager = WindowManager()
    private var item: NSStatusItem!
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Ignore duplicate launches without disturbing the already-running manager.
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "dev.compo.app").count > 1 {
            NSApp.terminate(nil)
            return
        }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = Brand.menuIcon()
        item.button?.toolTip = "compo.sh — Window Manager"
        item.button?.setAccessibilityLabel("Open compo window controls")
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        manager.start()
        guard !LaunchBehavior.isLoginLaunch(NSAppleEventManager.shared().currentAppleEvent) else { return }
        showPanel()
        if !manager.trusted, let window {
            let alert = NSAlert()
            alert.messageText = "Let compo Arrange Your Windows"
            alert.informativeText = "compo needs Accessibility access to read window positions, move and resize windows, and focus the window you choose. It does not record your screen. You control this permission in System Settings. Tiling stays paused until you enable it."
            alert.addButton(withTitle: "Allow Accessibility Access…")
            alert.addButton(withTitle: "Not Now")
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn { self?.manager.requestAccess() }
            }
        }
    }

    @objc private func togglePanel() {
        showPanel()
    }

    private func showPanel() {
        if window == nil {
            let controller = NSHostingController(rootView:
                ScrollView { ControlPanel(manager: manager) }
                    .frame(width: 380, height: 620)
                    .preferredColorScheme(.dark)
            )
            let panel = NSWindow(contentViewController: controller)
            panel.title = "compo.sh"
            panel.styleMask = [.titled, .closable, .miniaturizable]
            panel.isReleasedWhenClosed = false
            panel.center()
            window = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.deminiaturize(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { manager.stop() }
}

enum Brand {
    static let accent = Color(red: 0.56, green: 0.94, blue: 0.72)

    static func menuIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 19, height: 19), flipped: false) { _ in
            NSColor.black.setFill()
            for rect in [NSRect(x: 1, y: 2, width: 7, height: 15),
                         NSRect(x: 10, y: 10, width: 8, height: 7),
                         NSRect(x: 10, y: 2, width: 8, height: 6)] {
                NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

struct TileMark: View {
    var body: some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4).frame(width: 16)
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                RoundedRectangle(cornerRadius: 4)
            }.frame(width: 18)
        }
        .foregroundStyle(Brand.accent)
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
    }
}

struct ControlPanel: View {
    @ObservedObject var manager: WindowManager
    @State private var showKeys = false
    @State private var workspaceName = ""
    @State private var selectedWorkspace: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                TileMark()
                VStack(alignment: .leading, spacing: 1) {
                    Text("compo.sh").font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("A little order. A lot of room.").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(manager.enabled && manager.trusted ? "TILING" : "PAUSED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Brand.accent.opacity(0.12), in: Capsule())
                    .foregroundStyle(Brand.accent)
            }

            if let message = manager.message {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(message).fixedSize(horizontal: false, vertical: true)
                    Button { manager.message = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss message")
                }.font(.system(size: 11)).foregroundStyle(.orange)
            }

            if !manager.trusted {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Accessibility Access Required", systemImage: "hand.raised")
                        .font(.system(size: 13, weight: .semibold))
                    Text("compo uses Accessibility to read window positions, move and resize windows, and focus your chosen window. It does not record your screen. Enable compo in System Settings, then return here and start tiling.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Allow Accessibility Access…", action: manager.requestAccess)
                        .buttonStyle(.borderedProminent).tint(Brand.accent).foregroundStyle(.black)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Automatic Tiling").font(.system(size: 13, weight: .semibold))
                    Text(manager.enabled ? "New windows fall into place." : "Your windows stay where you put them.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Automatic Tiling", isOn: $manager.enabled).labelsHidden()
                    .toggleStyle(.switch).tint(Brand.accent).disabled(!manager.trusted)
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("App-Aware Layout", isOn: $manager.appAwareLayout)
                    .toggleStyle(.switch).tint(Brand.accent).font(.system(size: 12, weight: .semibold))
                Text(manager.appAwareLayout
                     ? "Browsers get wide panes. Terminals and documents get tall panes. Browsers get more room than terminals."
                     : "Choose a layout to arrange every window the same way.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text("LAYOUT").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(manager.windowCount) windows · \(manager.floatingCount) floating")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    ForEach(CompoCore.Layout.allCases) { layout in
                        Button { manager.appAwareLayout = false; manager.layout = layout } label: {
                            VStack(spacing: 9) {
                                LayoutPreview(layout: layout).frame(height: 42)
                                Text(layout.rawValue).font(.system(size: 11, weight: .medium))
                            }
                            .frame(maxWidth: .infinity).padding(10)
                            .background(!manager.appAwareLayout && manager.layout == layout ? Brand.accent.opacity(0.13) : .white.opacity(0.04),
                                        in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .stroke(!manager.appAwareLayout && manager.layout == layout ? Brand.accent : .clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(layout.rawValue) layout")
                        .accessibilityAddTraits(!manager.appAwareLayout && manager.layout == layout ? .isSelected : [])
                    }
                }
            }

            VStack(spacing: 12) {
                HStack {
                    Text("Window Gap").font(.system(size: 12))
                    Slider(value: $manager.gap, in: 0...32, step: 2).accessibilityLabel("Window gap")
                    Text("\(Int(manager.gap)) pt").font(.system(size: 11, design: .monospaced)).frame(width: 39, alignment: .trailing)
                }
                if !manager.appAwareLayout && manager.layout == .stack {
                    HStack {
                        Text("Main Width").font(.system(size: 12))
                        Slider(value: $manager.ratio, in: 0.25...0.75, step: 0.05).accessibilityLabel("Main window width")
                        Text("\(Int((manager.ratio * 100).rounded()))%")
                            .font(.system(size: 11, design: .monospaced)).frame(width: 39, alignment: .trailing)
                    }
                }
            }.tint(Brand.accent)

            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Snap Edges", isOn: $manager.snapEdges)
                Text("Preview halves, quarters and fill while dragging. While tiling is active, macOS edge tiling is disabled. Your previous macOS settings return when this is off, tiling is paused, or compo.sh quits.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Toggle("Drag to Swap", isOn: $manager.dragSwap)
                Toggle("Disable All Animations", isOn: $manager.disableAnimations)
                if manager.snapEdges {
                    HStack {
                        Text("Edge Reach")
                        Slider(value: $manager.edgeDistance, in: 8...48, step: 4).accessibilityLabel("Edge snap reach")
                        Text("\(Int(manager.edgeDistance)) pt").font(.system(size: 11, design: .monospaced))
                    }
                }
                HStack {
                    Button("Edit App Rules…", action: manager.editRules)
                    Button("Reload Rules", action: manager.reloadRules)
                }
                Text("Use exact bundle IDs to override browser, terminal, document or other roles and float apps. Retile Now clears manual placements.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.font(.system(size: 12)).toggleStyle(.switch).tint(Brand.accent)
            Divider()
            Toggle("Launch at Login", isOn: Binding(get: { manager.loginEnabled }, set: manager.setLogin))
                .toggleStyle(.switch).tint(Brand.accent).font(.system(size: 12))
            Text("Starts silently in the menu bar. Settings and login registration survive updates when you replace this app in Applications. Click its menu bar icon to open controls.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if manager.loginNeedsApproval {
                Button("Approve in Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                    .font(.system(size: 11))
            }

            DisclosureGroup("Keyboard Shortcuts", isExpanded: $showKeys) {
                VStack(spacing: 8) {
                    ForEach(manager.shortcuts) { binding in
                        shortcut(binding.action, binding.display)
                    }
                    HStack {
                        Button("Edit Shortcuts…", action: manager.editShortcuts)
                        Button("Reload Shortcuts", action: manager.reloadShortcuts)
                    }
                    Text("Edit keys and modifiers in JSON. Duplicate or unavailable shortcuts keep previous working bindings.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }.padding(.top, 10)
            }.font(.system(size: 12)).tint(.secondary)

            Divider()
            Toggle("Show Desktop Indicator", isOn: $manager.showDesktopIndicator)
                .toggleStyle(.switch).tint(Brand.accent).font(.system(size: 12))
            VStack(alignment: .leading, spacing: 10) {
                Text("Saved Workspaces").font(.system(size: 12, weight: .semibold))
                HStack {
                    TextField("Workspace name", text: $workspaceName)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("New workspace name")
                    Button("Save") { manager.saveWorkspace(name: workspaceName) }
                        .disabled(workspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !manager.trusted || manager.restoringWorkspace)
                }
                if !manager.workspaces.isEmpty {
                    Picker("Workspace", selection: $selectedWorkspace) {
                        Text("Choose…").tag(Optional<UUID>.none)
                        ForEach(manager.workspaces) { workspace in Text(workspace.name).tag(Optional(workspace.id)) }
                    }
                    HStack {
                        Button(manager.restoringWorkspace ? "Restoring…" : "Restore") {
                            if let id = selectedWorkspace { manager.restoreWorkspace(id) }
                        }.disabled(selectedWorkspace == nil || manager.restoringWorkspace || !manager.trusted || !manager.enabled)
                        Button("Delete") {
                            if let id = selectedWorkspace { manager.deleteWorkspace(id); selectedWorkspace = nil }
                        }.disabled(selectedWorkspace == nil || manager.restoringWorkspace)
                    }
                }
                Text("Saves apps, displays and pane sizes. Restore opens missing apps and matches visible windows by order within each app. Open documents yourself before restoring.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.font(.system(size: 12))
            Button("Export Diagnostics…", action: manager.exportDiagnostics).font(.system(size: 11))

            HStack {
                Button("Open Guide PDF…") {
                    if let url = Bundle.main.url(forResource: "compo.sh-guide", withExtension: "pdf") {
                        if !NSWorkspace.shared.open(url) { manager.message = "Could not open the guide. Choose a default PDF viewer in Finder." }
                    } else { manager.message = "The guide is missing. Reinstall the complete compo.sh app." }
                }
                Spacer()
            }.font(.system(size: 11))

            HStack {
                Button("Retile Now") { manager.perform(.retile) }.disabled(!manager.trusted || !manager.enabled)
                Button("Undo") { manager.perform(.undo) }.disabled(!manager.canUndo || !manager.trusted || !manager.enabled)
                Spacer()
                Button("Quit compo.sh") { NSApp.terminate(nil) }
            }.font(.system(size: 11)).buttonStyle(.borderless)
        }
        .padding(22).frame(width: 380)
        .background(Color(red: 0.065, green: 0.085, blue: 0.08))
        .preferredColorScheme(.dark)
    }

    private func shortcut(_ title: String, _ keys: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(keys).font(.system(size: 11, weight: .medium, design: .monospaced))
        }
    }
}

struct LayoutPreview: View {
    let layout: CompoCore.Layout
    var body: some View {
        GeometryReader { geometry in
            let frames = layout.frames(count: 3, in: CGRect(origin: .zero, size: geometry.size), gap: 3, ratio: 0.56)
            ForEach(frames.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Brand.accent.opacity(index == 0 ? 0.95 : 0.35))
                    .frame(width: frames[index].width, height: frames[index].height)
                    .position(x: frames[index].midX, y: frames[index].midY)
            }
        }.accessibilityHidden(true)
    }
}
