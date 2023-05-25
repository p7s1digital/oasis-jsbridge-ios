import XCTest
import JavaScriptCore
@testable import OasisJSBridge

final class LocalStorageTests: XCTestCase {
    
    func testLocalStorage() {
        var interpreter = JavascriptInterpreter()

        do {
            // remove item in case previous failed test didn't clear the storage
            // setItem and check if getItem returns the same object
            let expectation = self.expectation(description: "setItem")
            interpreter.evaluateString(js: """
                localStorage.removeItem("test");
                localStorage.setItem("test", '123');
                localStorage.setItem("test2", '456');
                localStorage.getItem("test");
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
                localStorage.getItem("test");
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
                localStorage.getItem("test");
            """) { value, error in
                XCTAssertEqual(value?.toInt32(), 123)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
        do {
            // test clear(), getItem should return undefined
            let expectation = self.expectation(description: "clear")
            interpreter.evaluateString(js: """
                localStorage.clear();
                localStorage.getItem("test");
            """) { value, error in
                XCTAssertTrue(value?.isUndefined ?? false)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
    }
    
    
    func testLocalStorage_withMultipleInterpreters() {
        // Interpreter with a namespace
        var interpreter = JavascriptInterpreter(namespace: "test_namespace1")

        do {
            // remove item in case previous failed test didn't clear the storage
            // setItem and check if getItem returns the same object
            let expectation = self.expectation(description: "setItem")
            interpreter.evaluateString(js: """
                localStorage.removeItem("test");
                localStorage.setItem("test", '123');
                localStorage.setItem("test2", '456');
                localStorage.getItem("test");
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
                localStorage.getItem("test");
            """) { value, error in
                XCTAssertEqual(value?.toInt32(), 123)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }

        // re-create interpreter with a new JSContext & namespace
        interpreter = JavascriptInterpreter(namespace: "test_namespace2")

        do {
            // test if item from the previous interpreter is still available
            let expectation = self.expectation(description: "getItem-restore")
            interpreter.evaluateString(js: """
                localStorage.getItem("test");
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
                localStorage.clear();
                localStorage.getItem("test");
            """) { value, error in
                XCTAssertTrue(value?.isUndefined ?? false)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1)
        }
    }
    
    func testLocalStorage_withMultipleStorages() {
        // create a user defaults object, initialized with specified database name.
        let userDefaults = UserDefaults(suiteName: #file)!
        
        // create seperate instances of storages
        let localStorage1 = LocalStorage(with: "test1", userDefaults: userDefaults)
        let localStorage2 = LocalStorage(with: "test2", userDefaults: userDefaults)
        
        // set values against same key in both storages
        localStorage1.setItem("key", "value1")
        localStorage2.setItem("key", "value2")
        
        // test keys in both storages are not same
        XCTAssertEqual(localStorage1.getItem("key"), "value1")
        XCTAssertEqual(localStorage2.getItem("key"), "value2")
        
        // cleanup
        userDefaults.removePersistentDomain(forName: #file)
        
        // test if clean up worked
        XCTAssertNil(localStorage1.getItem("key"))
        XCTAssertNil(localStorage2.getItem("key"))

    }
}
