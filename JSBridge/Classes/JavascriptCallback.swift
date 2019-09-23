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

public protocol JavascriptCallbackProtocol: class {
    func onResult(value: JSValue?, error: JSValue?)
}

/**
 * Use JavascriptCallback to pass callback functions to
 *   javascriptInterpreter.evaluate(functionName:parameters:)
 * with a signature callback(T, NSError).
 *
 * We can't pass Swift closures directly, because there's no way
 * to make those typed with generics.
 * Therefore as a workaround JavascriptCallback<T> has been created.
 */
public class JavascriptCallback<T: Codable> : JavascriptCallbackProtocol {

    var callback: ((_: T?, _: JSBridgeError?) -> Void)

    public init(callback: @escaping ((_: T?, _: JSBridgeError?) -> Void)) {
        self.callback = callback
    }

    public func onResult(value: JSValue?, error: JSValue?) {
        guard let value = value, !value.isUndefined, !value.isNull else {
            callback(nil, JSBridgeError.from(jsValue: error))
            return
        }
        let converter = JavascriptConverter<T>(value: value)
        if let convertedObject = converter.swiftObject() {
            callback(convertedObject, nil)
        } else {
            callback(nil, JSBridgeError(type: .jsConversionFailed))
        }
    }
}
