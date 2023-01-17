/*
 * Copyright (C) 2019 ProSiebenSat1.Digital GmbH.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import XCTest
import JavaScriptCore
import OHHTTPStubs
@testable import OasisJSBridge

@objc private protocol VehicleProtocol: JSExport {
    var brand: String? { get }
}
@objc private class Vehicle: NSObject, VehicleProtocol {
    var brand: String?
}

@objc private protocol AdSchedulerProtocol: JSExport {
    func update(_ payload: Any?) -> JSValue
    func fullfillExpectationAfterResolve()
}
@objc private class AdScheduler: NSObject, AdSchedulerProtocol {
    let interpreter: JavascriptInterpreterProtocol
    let expectation: XCTestExpectation

    init(interpreter: JavascriptInterpreterProtocol, expectation: XCTestExpectation) {
        self.interpreter = interpreter
        self.expectation = expectation
    }

    func update(_ payload: Any?) -> JSValue {
        let promiseWrapper = NativePromise(interpreter: interpreter)

        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            promiseWrapper.resolve(arguments: [["native" : "ios"]])
        }

        return promiseWrapper.promise
    }

    func fullfillExpectationAfterResolve() {
        expectation.fulfill()
    }
}

class JavascriptInterpreterTest: XCTestCase {
    private let native = Native()

    override class func tearDown() {
        HTTPStubs.removeAllStubs()
        super.tearDown()
    }

    func createJavascriptInterpreter() -> JavascriptInterpreter {
        let interpreter = JavascriptInterpreter()
        interpreter.jsContext.setObject(native, forKeyedSubscript: "native" as NSString)
        return interpreter
    }

    func testCreate() {
        // WHEN
        let subject = createJavascriptInterpreter()

        // THEN
        XCTAssertNotNil(subject)
    }

    func testStart() {
        // WHEN
        let subject = createJavascriptInterpreter()
        XCTAssertNotNil(subject)
    }

    func testEvaluateString() {
        // GIVEN
        let subject = createJavascriptInterpreter()
        XCTAssertNotNil(subject)

        let expectation = self.expectation(description: "js")

        // WHEN
        subject.evaluateString(js: "console.log(\"Logging evaluated string\");") { (_, _) in
            // THEN
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)
    }

    func testEvaluateLocalFile() {
        // GIVEN
        let subject = createJavascriptInterpreter()
        XCTAssertNotNil(subject)

        let expectation = self.expectation(description: "js")
        native.resetAndSetExpectation(expectation)

        // WHEN
        // Local resource file: test.js
        // - content:
        // sendEvent("localFileEvent", {isHere: true});
        subject.evaluateLocalFile(bundle: Bundle.module, filename: "test.js")

        self.waitForExpectations(timeout: 10)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 1)
        guard let event = native.receivedEvents.first, let payload = event.payload as? NSDictionary else {
            return XCTFail("Unexpected payload")
        }
        XCTAssertEqual(event.name, "localFileEvent")
        XCTAssertEqual((payload["isHere"] as? NSNumber)?.boolValue, true)
    }

    func testConsole() {
        // WHEN
        let subject = createJavascriptInterpreter()

        // THEN
        let js = """
            console.log("this is a console log");
            console.trace("this is a console trace");
            console.info("this is a console info");
            console.warn("this is a console warn");
            console.error("this is a console error");
            console.dir("this is a console dir");
            console.assert(true, "this is a passed console assert");
            console.assert(false, "this is a failed console assert");
        """
        let expectation = self.expectation(description: "js")
        subject.evaluateString(js: js) { (_, _) in
            // THEN
            expectation.fulfill()
        }

        // THEN
        self.waitForExpectations(timeout: 10)
    }

    func testSetObject() {
        // GIVEN
        let javascriptInterpreter = JavascriptInterpreter()

        // WHEN
        let getName: @convention(block) (String) -> String? = { key in
            return "Firstname Lastname"
        }

        let expectation = self.expectation(description: "testSetObject")
        javascriptInterpreter.setObject(getName, forKey: "getName")

        javascriptInterpreter.evaluateString(js: """
            getName()
        """) { (value, _) in
            if let value = value,
               value.isString,
               value.toString() == "Firstname Lastname" {
                expectation.fulfill()
            }
        }

        // THEN
        self.waitForExpectations(timeout: 3)
    }

    func testIsFunction() {
        let javascriptInterpreter = JavascriptInterpreter()
        javascriptInterpreter.evaluateString(js: """
            var test = {
              innerTest: {
                testMethod: function(firstname, lastname, callback) {
                }
              }
            };
        """)

        let expectation1 = self.expectation(description: "test.innerTest.testMethod")
        javascriptInterpreter.isFunction(object: nil, functionName: "test.innerTest.testMethod") { (isFunction) in
            if isFunction {
                expectation1.fulfill()
            }
        }

        let expectation2 = self.expectation(description: "test.innerTest")
        javascriptInterpreter.isFunction(object: nil, functionName: "test.innerTest") { (isFunction) in
            if !isFunction {
                expectation2.fulfill()
            }
        }

        let expectation3 = self.expectation(description: "test")
        javascriptInterpreter.isFunction(object: nil, functionName: "test") { (isFunction) in
            if !isFunction {
                expectation3.fulfill()
            }
        }

        let expectation4 = self.expectation(description: "foobar")
        javascriptInterpreter.isFunction(object: nil, functionName: "foobar") { (isFunction) in
            if !isFunction {
                expectation4.fulfill()
            }
        }

        self.waitForExpectations(timeout: 10)
    }

    class Person: Codable {
        var firstname: String?
        var lastname: String?
    }

    func testCallbackCall() {
        let javascriptInterpreter = JavascriptInterpreter()
        javascriptInterpreter.evaluateString(js: """
            var testObject = {
              testMethod: function(firstname, lastname, callback) {
                setTimeout(function() {
                  var persons = [{
                    firstname: "Someone",
                    lastname: "Else",
                  }, {
                    firstname: firstname,
                    lastname: lastname,
                  }];
                  callback(persons, null);
                }, 3000);
              }
            };
        """)

        let callbackExpectation = self.expectation(description: "callback")
        javascriptInterpreter.call(object: nil, functionName: "testObject.testMethod",
                                       arguments: ["Tester", "Blester", JavascriptCallback<[Person]>(callback: { (value, error) in

            callbackExpectation.fulfill()
            XCTAssertNil(error)
            guard let persons = value,
                  let person = persons.last
            else {
                XCTAssert(false)
                return
            }
            XCTAssertEqual(person.firstname, "Tester")
            XCTAssertEqual(person.lastname, "Blester")
        })], completion: { _ in

        })

        self.waitForExpectations(timeout: 10)
    }

    func testPromise() {
        let js = JavascriptInterpreter()
        js.evaluateString(js: """
            function getDelayedMessage() {
              return new Promise(function(resolve, reject) {
                setTimeout(function() {
                  console.log("JS: MESSAGE RESOLVED");
                  resolve({ firstname: "Tester", lastname: "Blester"});
                }, 2000);
              }).then(function(response) {
                console.log("JS: then called1 " + response);
                return response;
              }).then(function(response) {
                console.log("JS: then called2 " + response);
                return response;
              });
            }
        """)

        let callbackExpectation = self.expectation(description: "callback")

        js.callWithPromise(object: nil, functionName: "getDelayedMessage", arguments: []).then { (value: Person) in
            XCTAssertEqual(value.firstname, "Tester")
            XCTAssertEqual(value.lastname, "Blester")
            callbackExpectation.fulfill()
        }.except { (_) in
            XCTAssert(false)
        }

        self.waitForExpectations(timeout: 5)
    }
    func testFastResolvePromise() {
        let js = JavascriptInterpreter()
        js.evaluateString(js: """
            function getDelayedMessage() {
              return new Promise(function(resolve, reject) {
                console.log("JS: MESSAGE RESOLVED");
                resolve({ firstname: "Tester", lastname: "Blester"});
              });
            }
        """)

        let callbackExpectation = self.expectation(description: "callback")

        js.callWithPromise(object: nil, functionName: "getDelayedMessage", arguments: []).then { (value: Person) in
            XCTAssertEqual(value.firstname, "Tester")
            XCTAssertEqual(value.lastname, "Blester")
            callbackExpectation.fulfill()
        }.except { (_) in
            XCTAssert(false)
        }

        self.waitForExpectations(timeout: 5)
    }

    func testFailingPromise() {
        let js = JavascriptInterpreter()
        js.evaluateString(js: """
            function getDelayedMessage() {
              return new Promise(function(resolve, reject) {
                setTimeout(function() {
                  console.log("JS: MESSAGE REJECTED");
                  reject({ code: 123, message: "Something went wrong."});
                }, 1000);
              });
            }
        """)

        let callbackExpectation = self.expectation(description: "callback")

        js.callWithPromise(object: nil, functionName: "getDelayedMessage", arguments: []).then { (_: Person) in
            XCTAssert(false)
        }.except { (error) in
            XCTAssertEqual(error.code, 123)
            XCTAssertEqual(error.message, "Something went wrong.")
            callbackExpectation.fulfill()
        }

        self.waitForExpectations(timeout: 5)
    }

    func testExample() {
        let toUppercase: @convention(block) (String) -> String = { $0.uppercased() }
        let expectation = self.expectation(description: "callback")

        let interpreter = JavascriptInterpreter()
        interpreter.setObject(toUppercase, forKey: "toUppercase")
        interpreter.evaluateString(js: """
            var testObject = {
              testMethod: function(vehicle, callback) {
                return toUppercase(vehicle.brand);
              }
            };
        """)
        let vehicle = Vehicle()
        vehicle.brand = "bmw"
        interpreter.call(object: nil, functionName: "testObject.testMethod", arguments: [vehicle], completion: { value in
            XCTAssert(value?.isString ?? false)
            XCTAssertEqual(value?.toString(), "BMW")
            expectation.fulfill()
        })

        self.waitForExpectations(timeout: 3)
    }

    func testNativePromise() {
        let js = JavascriptInterpreter()
        js.evaluateString(js: """
            addScheduler = (scheduler) => {
              setTimeout( () => {
                scheduler.update({"id": "123"}).then( (currentAdSchedule) => {
                  scheduler.fullfillExpectationAfterResolve();
                })
              }, 1000);
            };
        """)

        let callbackExpectation = self.expectation(description: "callback")
        let scheduler = AdScheduler(interpreter: js, expectation: callbackExpectation)

        js.call(object: nil, functionName: "addScheduler", arguments: [scheduler], completion: { _ in })

        self.waitForExpectations(timeout: 10)
    }
}
