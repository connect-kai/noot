import XCTest
@testable import Noot

final class GlobalDoubleTapMonitorTests: XCTestCase {
    func testDeniedPermissionNeverRegistersKeyboardMonitoring() {
        var registrations = 0
        let monitor = GlobalDoubleTapMonitor(
            isTrusted: { false },
            addMonitor: { _ in registrations += 1; return NSObject() },
            removeMonitor: { _ in XCTFail("No monitor should exist without permission") })

        for _ in 0..<10 { monitor.refresh(enabled: true) { _ in } }

        XCTAssertEqual(registrations, 0, "Repeated permission checks must not invoke the API that can prompt")
    }

    func testPermissionChangesInstallOnceAndRemoveTheRegisteredMonitor() {
        var trusted = false
        var registrations = 0
        let token = NSObject()
        var removed: [NSObject] = []
        let monitor = GlobalDoubleTapMonitor(
            isTrusted: { trusted },
            addMonitor: { _ in registrations += 1; return token },
            removeMonitor: { removed.append($0 as! NSObject) })

        monitor.refresh(enabled: true) { _ in }
        trusted = true
        for _ in 0..<10 { monitor.refresh(enabled: true) { _ in } }
        XCTAssertEqual(registrations, 1)

        trusted = false
        for _ in 0..<10 { monitor.refresh(enabled: true) { _ in } }
        XCTAssertEqual(removed.count, 1)
        XCTAssertTrue(removed.first === token)
        XCTAssertEqual(registrations, 1)

        trusted = true
        monitor.refresh(enabled: true) { _ in }
        XCTAssertEqual(registrations, 2)
    }

    func testDisablingDoubleTapRemovesMonitoringUntilEnabledAgain() {
        var registrations = 0
        var removals = 0
        var trustChecks = 0
        let monitor = GlobalDoubleTapMonitor(
            isTrusted: { trustChecks += 1; return true },
            addMonitor: { _ in registrations += 1; return NSObject() },
            removeMonitor: { _ in removals += 1 })

        monitor.refresh(enabled: false) { _ in }
        XCTAssertEqual(trustChecks, 0)
        XCTAssertEqual(registrations, 0)
        monitor.refresh(enabled: true) { _ in }
        monitor.refresh(enabled: false) { _ in }
        monitor.refresh(enabled: false) { _ in }
        XCTAssertEqual(removals, 1)
        monitor.refresh(enabled: true) { _ in }
        XCTAssertEqual(registrations, 2)
    }

    func testFailedRegistrationDoesNotCauseRepeatedRequests() {
        var registrations = 0
        let monitor = GlobalDoubleTapMonitor(
            isTrusted: { true },
            addMonitor: { _ in registrations += 1; return nil },
            removeMonitor: { _ in XCTFail("Registration failed, so there is nothing to remove") })

        for _ in 0..<10 { monitor.refresh(enabled: true) { _ in } }

        XCTAssertEqual(registrations, 1)
    }

    func testDeinitializationRemovesMonitoring() {
        var removals = 0
        var monitor: GlobalDoubleTapMonitor? = GlobalDoubleTapMonitor(
            isTrusted: { true },
            addMonitor: { _ in NSObject() },
            removeMonitor: { _ in removals += 1 })
        monitor?.refresh(enabled: true) { _ in }

        monitor = nil

        XCTAssertEqual(removals, 1)
    }
}
