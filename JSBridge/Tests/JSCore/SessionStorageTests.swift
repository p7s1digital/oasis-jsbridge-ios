import XCTest
import JavaScriptCore
@testable import OasisJSBridge

final class SessionStorageTests: XCTestCase {
    func testSessionStorage() {
        var interpreter = JavascriptInterpreter()

        do {
            // setItem and check if getItem returns the same object
            let expectation = self.expectation(description: "setItem")
            interpreter.evaluateString(js: """
                sessionStorage.setItem("test", '123');
                sessionStorage.setItem("test2", '456');
                sessionStorage.getItem("test");
            """) { value, error in
                XCTAssertEqual(value?.toInt32(), 123)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
        do {
            // test if item from previous call is still available
            let expectation = self.expectation(description: "getItem")
            interpreter.evaluateString(js: """
                sessionStorage.getItem("test");
            """) { value, error in
                XCTAssertEqual(value?.toInt32(), 123)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }

        // re-create interpreter with a new JSContext
        interpreter = JavascriptInterpreter()

        do {
            // test if item from the previous interpreter is still available
            let expectation = self.expectation(description: "getItem-restore")
            interpreter.evaluateString(js: """
                sessionStorage.getItem("test");
            """) { value, error in
                XCTAssertTrue(value?.isUndefined ?? false)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
        do {
            // test clear(), getItem should return undefined
            let expectation = self.expectation(description: "clear")
            interpreter.evaluateString(js: """
                sessionStorage.setItem("test", '123');
                sessionStorage.clear();
                sessionStorage.getItem("test");
            """) { value, error in
                XCTAssertTrue(value?.isUndefined ?? false)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
    }
}
