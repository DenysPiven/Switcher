import AppKit
import ServiceManagement

let arguments = CommandLine.arguments
let isBundle = Bundle.main.bundlePath.hasSuffix(".app")

if arguments.contains("--test") {
    exit(SelfTest.run())
}
if arguments.contains("--uninstall") {
    if isBundle { try? SMAppService.mainApp.unregister() }
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited) // no Dock icon, no menu bar, no windows

// Start at login. Skipped if the user turned it off in System Settings.
if isBundle, SMAppService.mainApp.status == .notRegistered {
    try? SMAppService.mainApp.register()
}

let engine = Engine()

// Ask for Accessibility once; the system shows its own dialog.
AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }

// Keep trying until the user grants permission, then stay quiet.
if !(AXIsProcessTrusted() && engine.start()) {
    Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { timer in
        if AXIsProcessTrusted() && engine.start() { timer.invalidate() }
    }
}

app.run()
