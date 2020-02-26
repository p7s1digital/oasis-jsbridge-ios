🏝 Oasis JSBridge
===============

Evaluate JavaScript code and map values, objects and functions between Swift and JavaScript on iOS.  

Powered by:
- [JavascriptCore][JavascriptCore]


## Features

Based on [JavascriptCore][JavascriptCore] with additional support for:
 * two-way support for JS promises
 * polyfills for some JS runtime features (e.g. setTimeout, XmlHttpRequest, console, localStorage)


## Supported types

OasisJSBridge supports the same types as JavaScriptCore does. Swift (ObjC) types can be exported
to javascript using JSExport protocol.

Swift does not support promise/deffered calls yet, to support such APIs OasisJSBridge offers
JavascriptPromise and NativePromise objects.


## Usage

```swift
// define Swift type that can be sent to Javascript
@objc protocol VehicleProtocol: JSExport {
    var brand: String? { get }
}
@objc class Vehicle: NSObject, VehicleProtocol {
    var brand: String?
}
let vehicle = Vehicle()
vehicle.brand = "bmw"

// create an instance of JavascriptInterpreter
let interpreter = JavascriptInterpreter()

// define a function in Swift
let toUppercase: @convention(block) (String) -> String = { $0.uppercased() }
interpreter.setObject(toUppercase, forKey: "toUppercase")

// load Javascript, use previously defined toUppercase function
interpreter.evaluateString(js: """
    var testObject = {
      testMethod: function(vehicle, callback) {
        return toUppercase(vehicle.brand)
      }
    };
""")

// call Javascript function
interpreter.call(object: nil, functionName: "testObject.testMethod", arguments: [vehicle], completion: { value in
    XCTAssertEqual(value?.toString(), "BMW")
})

```


## License

```
Copyright (C) 2019 ProSiebenSat1.Digital GmbH.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```


 [JavascriptCore]: https://developer.apple.com/documentation/javascriptcore
