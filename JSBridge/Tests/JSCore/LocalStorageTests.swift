import XCTest
import JavaScriptCore
@testable import OasisJSBridge

final class LocalStorageTests: XCTestCase {
    
    func testLocalStorage() {
        
        var interpreter = JavascriptInterpreter(namespace: "localStorageInterpreter")

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
        interpreter = JavascriptInterpreter(namespace: "localStorageInterpreter")

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
        // interpreter with a new JSContext & new namespace
        var interpreter = JavascriptInterpreter(namespace: "localStorageInterpreter_1")

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

        // re-create interpreter with a new JSContext & new namespace
        interpreter = JavascriptInterpreter(namespace: "localStorageInterpreter_2")

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
        let localInterpreterStorage1 = LocalStorage(with: "testInterpreter_1", userDefaults: userDefaults)
        let localInterpreterStorage2 = LocalStorage(with: "testInterpreter_2", userDefaults: userDefaults)
        
        // set values against same key in both storages
        localInterpreterStorage1.setItem("key", "value1")
        localInterpreterStorage2.setItem("key", "value2")
        
        // test keys in both storages are not same
        XCTAssertEqual(localInterpreterStorage1.getItem("key"), "value1")
        XCTAssertEqual(localInterpreterStorage2.getItem("key"), "value2")
        
        // cleanup
        userDefaults.removePersistentDomain(forName: #file)
        
        // test if clean up worked
        XCTAssertNil(localInterpreterStorage1.getItem("key"))
        XCTAssertNil(localInterpreterStorage2.getItem("key"))

    }
}
