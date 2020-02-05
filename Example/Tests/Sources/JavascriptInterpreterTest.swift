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
import OHHTTPStubs
import JavaScriptCore

@testable import OasisJSBridge

@objc protocol NativeProtocol: JSExport {
    func sendEvent(_ eventName: String, _ payload: Any?)
}
@objc class Native: NSObject, NativeProtocol {

    var expectation: XCTestExpectation?
    var receivedEvents: [(name: String, payload: Any?)] = []

    func resetAndSetExpectation(_ expectation: XCTestExpectation) {
        receivedEvents = []
        self.expectation = expectation
    }

    func sendEvent(_ eventName: String, _ payload: Any?) {
        receivedEvents.append((name: eventName, payload: payload))
        expectation?.fulfill()
    }
}

@objc protocol AdSchedulerProtocol: JSExport {
    func update(_ payload: Any?) -> JSValue
    func fullfillExpectationAfterResolve()
}
@objc class AdScheduler: NSObject, AdSchedulerProtocol {

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
    private var stubbedRequests: [(url: String, response: String)] = []

    override func setUp() {
        super.setUp()
    }

    override class func tearDown() {
        OHHTTPStubs.removeAllStubs()
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
        let bundle = Bundle(for: type(of: self))
        subject.evaluateLocalFile(bundle: bundle, filename: "test.js")

        self.waitForExpectations(timeout: 10)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 1)
        let event = native.receivedEvents.first
        XCTAssertEqual(event?.name, "localFileEvent")
        if let payload = event?.payload as? NSDictionary,
           let isHere = payload["isHere"] as? NSNumber {
            XCTAssertTrue(isHere.boolValue)
        } else {
            XCTAssertTrue(false)
        }

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

    func testSetTimeout() {
        // GIVEN
        let timeoutCount = 100
        let subject = createJavascriptInterpreter()

        // WHEN
        var js = ""
        for i in 1...timeoutCount {
            js += "setTimeout(function() { native.sendEvent(\"timeout\(i)\", {done: true}); }, \(i * 10));"
        }
        subject.evaluateString(js: js, cb: nil)

        let expectation = self.expectation(description: "js")
        expectation.assertForOverFulfill = true  // already default
        expectation.expectedFulfillmentCount = timeoutCount
        native.resetAndSetExpectation(expectation)

        self.waitForExpectations(timeout: 10)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, timeoutCount)
        var index = 1
        native.receivedEvents.forEach { event in
            XCTAssertEqual(event.name, "timeout\(index)")
            index += 1
        }
    }

    func testClearTimeout() {
        // GIVEN
        let subject = createJavascriptInterpreter()

        // WHEN
        let js = """
            var timeout2Id = null;
            setTimeout(function() {
              native.sendEvent("timeout1");
              clearTimeout(timeout2Id);
            }, 100);
            timeout2Id = setTimeout(function() { native.sendEvent("timeout2"); }, 200);
            setTimeout(function() { native.sendEvent("timeout3"); }, 300);
        """
        subject.evaluateString(js: js, cb: nil)

        let expectation = self.expectation(description: "js")
        expectation.assertForOverFulfill = true  // already default
        expectation.expectedFulfillmentCount = 2
        native.resetAndSetExpectation(expectation)

        self.waitForExpectations(timeout: 10)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 2)
        XCTAssertEqual(native.receivedEvents[0].name, "timeout1")
        XCTAssertEqual(native.receivedEvents[1].name, "timeout3")
    }

    func testSetAndClearInterval() {
        // GIVEN
        let subject = createJavascriptInterpreter()

        // WHEN
        let js = """
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
        """
        subject.evaluateString(js: js, cb: nil)

        let expectation = self.expectation(description: "js")
        expectation.assertForOverFulfill = true  // already default
        expectation.expectedFulfillmentCount = 3
        native.resetAndSetExpectation(expectation)
        self.waitForExpectations(timeout: 10)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 3)
        XCTAssertEqual(native.receivedEvents[0].name, "interval1")
        XCTAssertEqual(native.receivedEvents[1].name, "interval2")
        XCTAssertEqual(native.receivedEvents[2].name, "interval3")
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

    func testXMLHTTPRequest() {
        // GIVEN
        let url = "https://test.url/api/request"
        let responseText = "{\"testKey\": \"testValue\"}"
        stubJsonRequest(url: url, responseText: responseText)

        let subject = createJavascriptInterpreter()

        // WHEN
        let js = """
            var xhr = new XMLHttpRequest();
            xhr.responseType = "json";
            xhr.open("GET", "\(url)");
            xhr.send();
            xhr.onload = function() {
                console.log("sending native event xhrDone, payload:", xhr.response, "...");
                native.sendEvent("xhrDone", xhr.response);
            }
        """
        subject.evaluateString(js: js, cb: nil)

        let expectation = self.expectation(description: "js")
        native.resetAndSetExpectation(expectation)

        self.waitForExpectations(timeout: 10)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 1)
        let event = native.receivedEvents[0]
        XCTAssertEqual(event.name, "xhrDone")
        if let payload = event.payload as? NSDictionary,
            let testKey = payload["testKey"] as? String {
            XCTAssertEqual(testKey, "testValue")
        } else {
            XCTAssertTrue(false)
        }

    }

    func testXMLHTTPRequest_abort() {
        // GIVEN
        let url = "https://test.url/api/request"
        let responseText = "{\"testKey\": \"testValue\"}"
        stubJsonRequest(url: url, responseText: responseText)

        let subject = createJavascriptInterpreter()

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
        subject.evaluateString(js: js, cb: nil)

        let expectation = self.expectation(description: "js")
        native.resetAndSetExpectation(expectation)

        self.waitForExpectations(timeout: 10)

        // THEN
        XCTAssertEqual(native.receivedEvents.count, 1)
        let event = native.receivedEvents[0]
        XCTAssertEqual(event.name, "xhrAborted")
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

    func testNativePromise() {
        let js = JavascriptInterpreter()
        js.evaluateString(js: """
            addScheduler = (scheduler) => {
              setTimeout( () => {
                scheduler.update({"id": "123"}).then( (currentAdSchedule) => {
                  scheduler.fullfillExpectationAfterResolve()
                })
              }, 1000)
            }
            """)

        let callbackExpectation = self.expectation(description: "callback")
        let scheduler = AdScheduler(interpreter: js, expectation: callbackExpectation)

        js.call(object: nil, functionName: "addScheduler", arguments: [scheduler], completion: {_ in })

        self.waitForExpectations(timeout: 10)
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

    // MARK: Private methods

    private func stubJsonRequest(url: String, responseText: String) {
        OHHTTPStubs.stubRequests(
            passingTest: { (request) -> Bool in
                guard let host = request.url?.host, let path = request.url?.path else {
                    return false
                }

                if url != "https://\(host)\(path)" {
                    return false  // not stubbed
                }

                return true
            },
            withStubResponse: { [weak self] (_) -> OHHTTPStubsResponse in
                let response = responseText
                self?.stubbedRequests.append((url: url, response: response))
                return OHHTTPStubsResponse(data: response.data(using: String.Encoding.utf8)!,
                                           statusCode: 200,
                                           headers: ["content-type": "application/json"])
            }
        )
    }
}
