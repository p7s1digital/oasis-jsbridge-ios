import XCTest
import JavaScriptCore
@testable import OasisJSBridge
import OHHTTPStubs
import OHHTTPStubsSwift

final class XMLHttpRequestTests: XCTestCase {
    private let timeout: TimeInterval = 1
    private let brokenURL = "h://& ?" // invalid both for browser and for Foundation.URL

    private var interpreter: JavascriptInterpreter!
    private var eventLogger: JSEventLogger!

    override func setUpWithError() throws {
        interpreter = JavascriptInterpreter()
        eventLogger = JSEventLogger()

        interpreter.jsContext.setObject(eventLogger, forKeyedSubscript: "native" as NSString)
    }

    override func tearDownWithError() throws {
        HTTPStubs.removeAllStubs()
    }
}

// MARK: - Event Tests

extension XMLHttpRequestTests {
    private var eventHandler: String {
        """
        function logEvent(type, xhr) {
          const readyState = (typeof xhr !== "undefined") ? xhr.readyState : 'null';
          native.sendEvent([type, readyState].join(' '));
        }
        function eventHandler(event) {
          logEvent(event.type, event.target);
        }
        """
    }

    private var eventProperties: String {
        ["onreadystatechange", "onload", "onsend", "onabort", "onerror"]
            .map { "xhr.\($0) = eventHandler;" }
            .joined(separator: "\n")
    }

    private var eventListeners: String {
        XMLHttpRequestEvent.EventType.allCases
            .map { "xhr.addEventListener('\($0.rawValue)', eventHandler);" }
            .joined(separator: "\n")
    }

    // MARK: - Event properties

    func testEvents_properties_abort() {
        // GIVEN
        let expectedEvents = """
        MANUAL 0
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventProperties)
        xhr.abort();
        logEvent('MANUAL', xhr);
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_properties_open() {
        // GIVEN
        let url = "https://test.url/api/request"
        let expectedEvents = """
        readystatechange 1
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventProperties)
        xhr.open("GET", "\(url)");
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_properties_open_brokenURL() {
        // GIVEN
        let url = brokenURL
        let expectedEvents = """
        readystatechange 1
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventProperties)
        xhr.open("GET", "\(url)");
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_properties_openAbort() {
        // GIVEN
        let url = "https://test.url/api/request"
        HTTPStubs.stubRequests(passingTest: isAbsoluteURLString(url)) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        let expectedEvents = """
        readystatechange 1
        MANUAL 0
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventProperties)
        xhr.open("GET", "\(url)");
        xhr.abort();
        logEvent('MANUAL', xhr);
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_properties_openSend() {
        // GIVEN
        let url = "https://test.url/api/request"
        HTTPStubs.stubRequests(passingTest: isAbsoluteURLString(url)) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        let expectedEvents = """
        readystatechange 1
        loadstart 1
        readystatechange 2
        readystatechange 3
        readystatechange 4
        load 4
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventProperties)
        xhr.open("GET", "\(url)");
        xhr.send();
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_properties_openSend_brokenURL() {
        // GIVEN
        let expectedEvents = """
        readystatechange 1
        loadstart 1
        readystatechange 4
        error 4
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventProperties)
        xhr.open("GET", "\(brokenURL)");
        xhr.send();
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_properties_openSendAbort() {
        // GIVEN
        let url = "https://test.url/api/request"
        HTTPStubs.stubRequests(passingTest: isAbsoluteURLString(url)) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        let expectedEvents = """
        readystatechange 1
        loadstart 1
        readystatechange 4
        abort 4
        MANUAL 0
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventProperties)
        xhr.open("GET", "\(url)");
        xhr.send();
        xhr.abort();
        logEvent('MANUAL', xhr);
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_properties_openSendError() {
        // GIVEN
        let url = "https://test.url/api/request"
        HTTPStubs.stubRequests(passingTest: isAbsoluteURLString(url)) { _ in
            HTTPStubsResponse(error: URLError(.resourceUnavailable))
        }

        let expectedEvents = """
        readystatechange 1
        loadstart 1
        readystatechange 4
        error 4
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventProperties)
        xhr.open("GET", "\(url)");
        xhr.send();
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_properties_send() {
        // GIVEN
        let expectedEvents = """
        MANUAL 0
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventProperties)
        xhr.send();
        logEvent('MANUAL', xhr);
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    // MARK: - Event listeners

    func testEvents_listeners_abort() {
        // GIVEN
        let expectedEvents = """
        MANUAL 0
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventListeners)
        xhr.abort();
        logEvent('MANUAL', xhr);
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_listeners_open() {
        // GIVEN
        let url = "https://test.url/api/request"
        let expectedEvents = """
        readystatechange 1
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventListeners)
        xhr.open("GET", "\(url)");
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_listeners_open_brokenURL() {
        // GIVEN
        let url = brokenURL
        let expectedEvents = """
        readystatechange 1
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventListeners)
        xhr.open("GET", "\(url)");
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_listeners_openAbort() {
        // GIVEN
        let url = "https://test.url/api/request"
        HTTPStubs.stubRequests(passingTest: isAbsoluteURLString(url)) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        let expectedEvents = """
        readystatechange 1
        MANUAL 0
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventListeners)
        xhr.open("GET", "\(url)");
        xhr.abort();
        logEvent('MANUAL', xhr);
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_listeners_openSend() {
        // GIVEN
        let url = "https://test.url/api/request"
        HTTPStubs.stubRequests(passingTest: isAbsoluteURLString(url)) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        let expectedEvents = """
        readystatechange 1
        loadstart 1
        readystatechange 2
        readystatechange 3
        progress 3
        readystatechange 4
        load 4
        loadend 4
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventListeners)
        xhr.open("GET", "\(url)");
        xhr.send();
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_listeners_openSend_brokenURL() {
        // GIVEN
        let expectedEvents = """
        readystatechange 1
        loadstart 1
        readystatechange 4
        error 4
        loadend 4
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventListeners)
        xhr.open("GET", "\(brokenURL)");
        xhr.send();
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_listeners_openSendAbort() {
        // GIVEN
        let url = "https://test.url/api/request"
        HTTPStubs.stubRequests(passingTest: isAbsoluteURLString(url)) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        let expectedEvents = """
        readystatechange 1
        loadstart 1
        readystatechange 4
        abort 4
        loadend 4
        MANUAL 0
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventListeners)
        xhr.open("GET", "\(url)");
        xhr.send();
        xhr.abort();
        logEvent('MANUAL', xhr);
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_listeners_openSendError() {
        // GIVEN
        let url = "https://test.url/api/request"
        HTTPStubs.stubRequests(passingTest: isAbsoluteURLString(url)) { _ in
            HTTPStubsResponse(error: URLError(.resourceUnavailable))
        }

        let expectedEvents = """
        readystatechange 1
        loadstart 1
        readystatechange 4
        error 4
        loadend 4
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventListeners)
        xhr.open("GET", "\(url)");
        xhr.send();
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

    func testEvents_listeners_send() {
        // GIVEN
        let expectedEvents = """
        MANUAL 0
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        eventLogger.configure(expectation: expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventListeners)
        xhr.send();
        logEvent('MANUAL', xhr);
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(eventLogger.events.map(\.name), expectedEvents)
    }

}
