import XCTest
import JavaScriptCore

@objc protocol JSEventLoggerProtocol: JSExport {
    func sendEvent(_ eventName: String, _ payload: Any?)
}

@objc final class JSEventLogger: NSObject, JSEventLoggerProtocol {
    private var expectation: XCTestExpectation?
    private(set) var events: [(name: String, payload: Any?)] = []

    func configure(expectation: XCTestExpectation) {
        events = []
        self.expectation = expectation
    }

    func sendEvent(_ name: String, _ payload: Any?) {
        events.append((name: name, payload: payload))
        expectation?.fulfill()
    }
}
