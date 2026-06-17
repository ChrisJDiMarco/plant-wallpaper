import AppKit
import Foundation

if CommandLine.arguments.contains("--interaction-self-test") {
    let succeeded = MainActor.assumeIsolated {
        GardenInteractionSelfTest.run()
    }
    exit(succeeded ? EXIT_SUCCESS : EXIT_FAILURE)
}

let application = NSApplication.shared
let applicationDelegate = AppDelegate()

application.delegate = applicationDelegate
application.setActivationPolicy(.accessory)
application.run()
