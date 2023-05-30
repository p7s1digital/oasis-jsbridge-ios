import XCTest
import JavaScriptCore
@testable import OasisJSBridge

final class JavascriptTimeoutsTests: XCTestCase {
    private var interpreter: JavascriptInterpreter!
    private var native: Native!

    override func setUpWithError() throws {
        interpreter = JavascriptInterpreter(namespace: "timeoutInterpreter")
        native = Native()

        interpreter.jsContext.setObject(native, forKeyedSubscript: "native" as NSString)
    }
}

// MARK: - Tests

extension JavascriptTimeoutsTests {
    func testSetTimeout() {
        // GIVEN
        let timeoutCount = 50

        // WHEN
        let expectation = self.expectation(description: "js")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = timeoutCount
        native.resetAndSetExpectation(expectation)

        interpreter.evaluateString(js: (1...timeoutCount).map {
            """
            setTimeout(function() {
              native.sendEvent("timeout_\($0)", { done: true });
            }, \($0 * 10));
            """
        }.joined(separator: "\n"))

        waitForExpectations(timeout: 1)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, timeoutCount)
        var index = 1
        native.receivedEvents.forEach { event in
            XCTAssertEqual(event.name, "timeout_\(index)")
            index += 1
        }
    }

    func testSetTimeoutNoDelayParameter() {
        // WHEN
        let expectation = self.expectation(description: "js")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1
        native.resetAndSetExpectation(expectation)

        interpreter.evaluateString(js: """
            setTimeout(function() {
              native.sendEvent("timeout", { done: true });
            });
        """)

        waitForExpectations(timeout: 1)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 1)
    }

    func testClearTimeout() {
        // WHEN
        let expectation = self.expectation(description: "js")
        expectation.assertForOverFulfill = false
        expectation.expectedFulfillmentCount = 2
        native.resetAndSetExpectation(expectation)

        interpreter.evaluateString(js: """
            var timeout2Id = null;
            setTimeout(function() {
              native.sendEvent("timeout1");
              clearTimeout(timeout2Id);
            }, 100);
            timeout2Id = setTimeout(function() { native.sendEvent("timeout2"); }, 200);
            setTimeout(function() { native.sendEvent("timeout3"); }, 300);
        """)

        waitForExpectations(timeout: 1)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 2)
        XCTAssertEqual(native.receivedEvents[0].name, "timeout1")
        XCTAssertEqual(native.receivedEvents[1].name, "timeout3")
    }

    func testSetAndClearInterval() {
        // WHEN
        let expectation = self.expectation(description: "js")
        expectation.assertForOverFulfill = true  // already default
        expectation.expectedFulfillmentCount = 3
        native.resetAndSetExpectation(expectation)

        interpreter.evaluateString(js: """
            console.log("typeof clearTimeout =", typeof clearTimeout);
            console.log("typeof clearInterval =", typeof clearInterval);
            var i = 1;
            var timeoutId = null;
            timeoutId = setInterval(function() {
              console.log("Inside interval");
              native.sendEvent("interval" + i);
              if (i == 3) {
                clearInterval(timeoutId);
              }
              i++;
            }, 50);
        """)

        waitForExpectations(timeout: 1)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 3)
        XCTAssertEqual(native.receivedEvents[0].name, "interval1")
        XCTAssertEqual(native.receivedEvents[1].name, "interval2")
        XCTAssertEqual(native.receivedEvents[2].name, "interval3")
    }

    func testSetTimeoutWithArguments() {
        // WHEN
        let expectation = self.expectation(description: "js")
        native.resetAndSetExpectation(expectation)

        interpreter.evaluateString(js: """
            setTimeout(function(a, b) {
                if (a == 1 && b == "blah") {
                    native.sendEvent("timeout", { done: true });
                }
            }, 10, 1, "blah");
        """)

        waitForExpectations(timeout: 1)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 1)
    }
}
