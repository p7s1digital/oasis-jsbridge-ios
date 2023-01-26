import XCTest
import JavaScriptCore

@objc protocol NativeProtocol: JSExport {
    func sendEvent(_ eventName: String, _ payload: Any?)
}

@objc final class Native: NSObject, NativeProtocol {
    private var expectation: XCTestExpectation?
    private(set) var receivedEvents: [(name: String, payload: Any?)] = []

    func resetAndSetExpectation(_ expectation: XCTestExpectation) {
        receivedEvents = []
        self.expectation = expectation
    }

    func sendEvent(_ eventName: String, _ payload: Any?) {
        receivedEvents.append((name: eventName, payload: payload))
        expectation?.fulfill()
    }
}

