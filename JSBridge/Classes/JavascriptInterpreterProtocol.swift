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

public protocol JavascriptInterpreterProtocol: class {

    func evaluateLocalFile(bundle: Bundle, filename: String, cb: (() -> Void)?)
    func evaluateString(js: String, cb: ((_: JSValue?, _: JSBridgeError?) -> Void)?)

    func callSynchronously(object: JSValue?, functionName: String, arguments: [Any]) -> JSValue

    func call(object: JSValue?,
              functionName: String,
              arguments: [Any],
              completion: @escaping (JSValue?) -> Void)
    func callWithCallback<T: Codable>(object: JSValue?,
                                      functionName: String,
                                      arguments: [Any],
                                      completion: @escaping (T?) -> Void)
    func callWithPromise<T: Codable>(object: JSValue?,
                                     functionName: String,
                                     arguments: [Any]) -> JavascriptPromise<T>
    func callWithValuePromise(object: JSValue?,
                              functionName: String,
                              arguments: [Any]) -> JavascriptValuePromise

    func setObject(_ object: Any!, forKey: String)
    func isFunction(object: JSValue?,
                    functionName: String,
                    completion: @escaping (Bool) -> Void)
}

public extension JavascriptInterpreterProtocol {

    func evaluateLocalFile(bundle: Bundle, filename: String) {
        evaluateLocalFile(bundle: bundle, filename: filename, cb: nil)
    }

    func evaluateString(js: String) {
        evaluateString(js: js, cb: nil)
    }

    func call(functionName: String, arguments: [Any], completion: @escaping (JSValue?) -> Void) {
        call(object: nil, functionName: functionName, arguments: arguments, completion: completion)
    }
}
