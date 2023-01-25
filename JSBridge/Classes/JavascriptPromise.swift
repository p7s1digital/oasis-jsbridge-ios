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

public class JavascriptPromise<T: Codable> {

    private var thenCallback: ((T) -> Void)?
    private var catchCallback: ((JSBridgeError) -> Void)?
    private var isCancelled = false

    public init() {}
    
    @discardableResult public func then(_ callback: @escaping ((T) -> Void)) -> JavascriptPromise<T> {
        thenCallback = callback
        return self
    }
    @discardableResult public func except(_ callback: @escaping ((JSBridgeError) -> Void)) -> JavascriptPromise<T> {
        catchCallback = callback
        return self
    }

    public func cancel() {
        isCancelled = true
    }

    public func setup(promiseValue: JSValue) {

        // Callbacks need to have a strong reference to JavascriptPromise<T>,
        // because noone else does, as client code usually doesn't.

        let javascriptValuePromise = JavascriptValuePromise()
        javascriptValuePromise.setup(promiseValue: promiseValue)
        javascriptValuePromise.then { (value) in

            let converter = JavascriptConverter<T>(value: value)
            if let convertedResult = converter.swiftObject() {
                self.thenCallback?(convertedResult)
            } else {
                self.catchCallback?(JSBridgeError(type: .jsConversionFailed))
            }
        }
        javascriptValuePromise.except { (error) in
            self.catchCallback?(error)
        }
    }

    public func fail() {
        self.catchCallback?(JSBridgeError(type: .jsPromiseFailed))
    }
}

public class JavascriptValuePromise {

    private var thenCallback: ((JSValue) -> Void)?
    private var catchCallback: ((JSBridgeError) -> Void)?
    private var isCancelled = false

    public init() {}

    @discardableResult public func then(_ callback: @escaping ((JSValue) -> Void)) -> JavascriptValuePromise {
        thenCallback = callback
        return self
    }
    @discardableResult public func except(_ callback: @escaping ((JSBridgeError) -> Void)) -> JavascriptValuePromise {
        catchCallback = callback
        return self
    }
    public func cancel() {
        isCancelled = true
    }

    public func setup(promiseValue: JSValue) {

        // We always set then/catch callbacks, even if they're not set by calling client code.
        // The reason behind this is our threading model of JavascriptInterpreter running
        // everything on a serial-bg-queue, so it might happen that when we set them,
        // the promise is already finished.

        // Callbacks need to have a strong reference to JavascriptPromise<T>,
        // because noone else does, as client code usually doesn't.

        let thenCallback: @convention(block) (JSValue?) -> Void = { (value) in

            DispatchQueue.main.async {
                if self.isCancelled {
                    return
                }
                guard let value = value else {
                    self.catchCallback?(JSBridgeError(type: .jsPromiseReturnedNilObj))
                    return
                }
                self.thenCallback?(value)
                self.thenCallback = nil
                self.catchCallback = nil
            }
        }
        promiseValue.invokeMethod("then", withArguments: [unsafeBitCast(thenCallback, to: AnyObject.self)])

        let catchCallback: @convention(block) (JSValue?) -> Void = { (value) in
            DispatchQueue.main.async {
                if self.isCancelled {
                    return
                }
                guard let value = value else {
                    self.catchCallback?(JSBridgeError(type: .jsPromiseReturnedNilObj))
                    return
                }
                self.catchCallback?(JSBridgeError.from(jsValue: value))
                self.thenCallback = nil
                self.catchCallback = nil
            }
        }
        promiseValue.invokeMethod("catch", withArguments: [unsafeBitCast(catchCallback, to: AnyObject.self)])
    }

    public func fail() {
        self.catchCallback?(JSBridgeError(type: .jsPromiseFailed))
    }
}
