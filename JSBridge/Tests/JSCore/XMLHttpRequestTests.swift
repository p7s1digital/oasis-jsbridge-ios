import XCTest
import JavaScriptCore
@testable import OasisJSBridge

final class XMLHttpRequestTests: XCTestCase {
    private let timeout: TimeInterval = 1
    private let brokenURL = "h://& ?" // invalid both for browser and for Foundation.URL

    private var interpreter: JavascriptInterpreter!
    private var native: Native!

    override func setUpWithError() throws {
        interpreter = JavascriptInterpreter(namespace: "httpReqInterpreter", testUrlSession: testSession)
        native = Native()
        
        interpreter.jsContext.setObject(native, forKeyedSubscript: "native" as NSString)
    }

    override func tearDownWithError() throws {
        HTTPStubs.removeAllStubs()
    }
}

// MARK: - General tests

extension XMLHttpRequestTests {
    func testText() {
        // GIVEN
        let url = "https://test.url/api/request"
        let responseText = "testValue"
        stubRequests(url: url, jsonResponse: responseText)

        let expectedPayloads: [NSString] = [
            responseText as NSString,
            responseText as NSString
        ]

        // WHEN
        let js = """
        var xhr = new XMLHttpRequest();
        xhr.responseType = "text";
        xhr.onload = function() {
          native.sendEvent("response", xhr.response);
          native.sendEvent("responseText", xhr.responseText);
        }
        xhr.open("GET", "\(url)");
        xhr.send();
        """
        interpreter.evaluateString(js: js)

        let expectation = self.expectation(description: "js")
        expectation.expectedFulfillmentCount = expectedPayloads.count
        native.resetAndSetExpectation(expectation)

        waitForExpectations(timeout: 1)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, expectedPayloads.count)
        for (received, expected) in zip(native.receivedEvents.map(\.payload), expectedPayloads) {
            XCTAssertEqual(received as? NSString, expected)
        }
    }

    func testJson() {
        // GIVEN
        let url = "https://test.url/api/request"
        let responseText = "{\"testKey\": \"testValue\"}"
        stubRequests(url: url, jsonResponse: responseText)

        let expectedPayloads: [NSDictionary?] = [
            ["testKey": "testValue"],
            nil
        ]

        // WHEN
        let js = """
        var xhr = new XMLHttpRequest();
        xhr.responseType = "json";
        xhr.onload = function() {
          native.sendEvent("response", xhr.response);
          native.sendEvent("responseText", xhr.responseText);
        }
        xhr.open("GET", "\(url)");
        xhr.send();
        """
        interpreter.evaluateString(js: js)

        let expectation = self.expectation(description: "js")
        expectation.expectedFulfillmentCount = expectedPayloads.count
        native.resetAndSetExpectation(expectation)

        waitForExpectations(timeout: 1)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, expectedPayloads.count)
        for (received, expected) in zip(native.receivedEvents.map(\.payload), expectedPayloads) {
            XCTAssertEqual(received as? NSDictionary, expected)
        }
    }

    func test_invalidURL() {
        // GIVEN
        let url = "https://test.url/api/request?code=${CODE}" // curly brackets are not allowed in URLs

        // WHEN
        let js = """
        var xhr = new XMLHttpRequest();
        xhr.responseType = "json";
        xhr.onload = function() {
          native.sendEvent("onload", xhr.response);
        }
        xhr.onerror = function() {
          native.sendEvent("onerror", xhr.response);
        }
        xhr.open("GET", "\(url)");
        xhr.send();
        """
        interpreter.evaluateString(js: js)

        let expectation = self.expectation(description: "js")
        native.resetAndSetExpectation(expectation)

        waitForExpectations(timeout: 1)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 1)
        let event = native.receivedEvents[0]
        XCTAssertEqual(event.name, "onerror")
    }

    func test_abort() {
        // GIVEN
        let url = "https://test.url/api/request"
        let responseText = "{\"testKey\": \"testValue\"}"
        stubRequests(url: url, jsonResponse: responseText)

        // WHEN
        let js = """
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "\(url)");
        xhr.send();
        xhr.onload = function() {
          console.log("sending native event xhrDone, payload:", xhr.response, "...");
          native.sendEvent("xhrDone", xhr.response);
        }
        xhr.onabort = function() {
          console.log("sending native event xhrAborted...");
          native.sendEvent("xhrAborted");
        }
        xhr.abort();
        """
        interpreter.evaluateString(js: js)

        let expectation = self.expectation(description: "js")
        native.resetAndSetExpectation(expectation)

        waitForExpectations(timeout: 1)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 1)
        let event = native.receivedEvents[0]
        XCTAssertEqual(event.name, "xhrAborted")
    }

    // This test ensures that the JsContext instance is not retained after destroying the
    // JavascriptInterpreter. This can be the for example the case if a JSValue instance is stored
    // in an exported object (like XMLHttpRequest) and not properly nulled.
    //
    // See also the "Managing Memory for Exported Objects" section in:
    // https://developer.apple.com/documentation/javascriptcore/jsvirtualmachine
    //
    // To provoke this behavior, you can try to comment out the line "self.onload = nil;" in
    // XMLHttpRequest:destroy and observe that the JSContext instance is still referenced

    /* Failing too often. Temporarily disabled.
    func testDestroy() {
        weak var weakJsInterpreter: JavascriptInterpreter? = nil
        weak var weakJsContext: JSContext? = nil

        autoreleasepool {
            var jsInterpreter: JavascriptInterpreter? = JavascriptInterpreter()
            weakJsInterpreter = jsInterpreter
            weakJsContext = jsInterpreter!.jsContext
            let jsInterpreterStartedExpectation = self.expectation(description: "startJsInterpreter")

            let js = """
                var xhr = new XMLHttpRequest();
                xhr.onload = function() {}
            """

            jsInterpreter?.evaluateString(js: js) { _ in
                jsInterpreter = nil

                jsInterpreterStartedExpectation.fulfill()
            }

            self.wait(for: [jsInterpreterStartedExpectation], timeout: 20)
        }

        if weakJsInterpreter != nil {
            Logger.warning("JavascriptInterpreter retain count AFTER: \(CFGetRetainCount(weakJsInterpreter))")
        }

        if weakJsContext != nil {
            Logger.warning("JsContext retain count AFTER: \(CFGetRetainCount(weakJsContext))")
        }

        XCTAssertNil(weakJsInterpreter)
        XCTAssertNil(weakJsContext)
    }
    */
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
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
        native.resetAndSetExpectation(expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventProperties)
        xhr.open("GET", "\(url)");
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
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
        native.resetAndSetExpectation(expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventProperties)
        xhr.open("GET", "\(url)");
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
    }

    func testEvents_properties_openAbort() {
        // GIVEN
        let url = "https://test.url/api/request"
        HTTPStubs.startInterceptingRequests()
        stubRequests(url: url) {
            HTTPResponseStub(data: Data(), statusCode: 200, headers: nil)
        }

        let expectedEvents = """
        readystatechange 1
        MANUAL 0
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
        HTTPStubs.stopInterceptingRequests()
    }

    func testEvents_properties_openSend() {
        // GIVEN
        let url = "https://test.url/api/request"
        
        HTTPStubs.startInterceptingRequests()
        stubRequests(url: url) {
            HTTPResponseStub(data: Data(), statusCode: 200, headers: nil)
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
        HTTPStubs.stopInterceptingRequests()
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
    }

    func testEvents_properties_openSendAbort() {
        // GIVEN
        let url = "https://test.url/api/request"
        HTTPStubs.startInterceptingRequests()
        stubRequests(url: url) {
            HTTPResponseStub(data: Data(), statusCode: 200, headers: nil)
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
        HTTPStubs.stopInterceptingRequests()
    }

    func testEvents_properties_openSendError() {
        // GIVEN
        let url = "https://test.url/api/request"
        stubRequests(url: url) {
            HTTPResponseStub(statusCode: 500, error: URLError(.resourceUnavailable))
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
        HTTPStubs.stopInterceptingRequests()
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
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
        native.resetAndSetExpectation(expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventListeners)
        xhr.open("GET", "\(url)");
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
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
        native.resetAndSetExpectation(expectation)

        let script = """
        \(eventHandler)
        var xhr = new XMLHttpRequest();
        \(eventListeners)
        xhr.open("GET", "\(url)");
        """
        interpreter.evaluateString(js: script)
        wait(for: [expectation], timeout: timeout)

        // THEN
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
    }

    func testEvents_listeners_openAbort() {
        // GIVEN
        let url = "https://test.url/api/request"
        stubRequests(url: url) {
            HTTPResponseStub(data: Data(), statusCode: 200)
        }

        let expectedEvents = """
        readystatechange 1
        MANUAL 0
        """.components(separatedBy: "\n")

        // WHEN
        let expectation = self.expectation(description: "Events received")
        expectation.expectedFulfillmentCount = expectedEvents.count
        expectation.assertForOverFulfill = false
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
        HTTPStubs.stopInterceptingRequests()
    }

    func testEvents_listeners_openSend() {
        // GIVEN
        let url = "https://test.url/api/request"
        stubRequests(url: url) {
            HTTPResponseStub(data: Data(), statusCode: 200)
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
        HTTPStubs.stopInterceptingRequests()
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
    }

    func testEvents_listeners_openSendAbort() {
        // GIVEN
        let url = "https://test.url/api/request"
        stubRequests(url: url) {
            HTTPResponseStub(data: Data(), statusCode: 200)
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
        HTTPStubs.stopInterceptingRequests()
    }

    func testEvents_listeners_openSendError() {
        // GIVEN
        let url = "https://test.url/api/request"
        stubRequests(url: url) {
            HTTPResponseStub(statusCode: 500, error: URLError(.resourceUnavailable))
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
        HTTPStubs.stopInterceptingRequests()
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
        native.resetAndSetExpectation(expectation)

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
        XCTAssertEqual(native.receivedEvents.map(\.name), expectedEvents)
    }
}
