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

import Foundation
import JavaScriptCore

public class NativePromise {

    weak var interpreter: JavascriptInterpreterProtocol?
    let promiseWrapper: JSValue?
    public var promise: JSValue {
        get {
            return promiseWrapper!.forProperty("promise")
        }
    }

    public init(interpreter: JavascriptInterpreterProtocol) {

        self.interpreter = interpreter

        self.promiseWrapper = interpreter.callSynchronously(object: nil, functionName: "jsBridgeCreatePromiseWrapper", arguments: [])
    }

    public func resolve(arguments: [Any]) {
        interpreter?.call(object: promiseWrapper,
                          functionName: "resolve",
                          arguments: arguments,
                          completion: { _ in })
    }
    public func reject(type: String, message: String) {
        interpreter?.call(object: promiseWrapper,
                          functionName: "reject",
                          arguments: [["type": type, "message": message]],
                          completion: { _ in })
    }
}
