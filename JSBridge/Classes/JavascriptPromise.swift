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
    
    private var thenResult: T?
    private var catchResult: JSBridgeError?
    
    private let thenlock = NSLock()
    private let catchlock = NSLock()
    
    public init() {}
    
    @discardableResult public func then(_ callback: @escaping ((T) -> Void)) -> JavascriptPromise<T> {
        thenlock.lock()
        thenCallback = callback
        if let result = thenResult {
            DispatchQueue.main.async {
                callback(result)
            }
        }
        thenlock.unlock()
        return self
    }
    @discardableResult public func except(_ callback: @escaping ((JSBridgeError) -> Void)) -> JavascriptPromise<T> {
        catchlock.lock()
        catchCallback = callback
        if let error = catchResult {
            DispatchQueue.main.async {
                callback(error)
            }
        }
        catchlock.unlock()
        return self
    }
    
    public func cancel() {
        isCancelled = true
    }
    
    private func callThen(_ result: T) {
        thenlock.lock()
        if let callback = thenCallback {
            DispatchQueue.main.async {
                callback(result)
            }
        } else {
            thenResult = result
        }
        thenlock.unlock()
    }
    
    private func callExcept(_ error: JSBridgeError) {
        catchlock.lock()
        if let callback = catchCallback {
            DispatchQueue.main.async {
                callback(error)
            }
        } else {
            catchResult = error
        }
        catchlock.unlock()
    }
    
    public func setup(promiseValue: JSValue) {
        
        // Callbacks need to have a strong reference to JavascriptPromise<T>,
        // because noone else does, as client code usually doesn't.
        
        let javascriptValuePromise = JavascriptValuePromise()
        javascriptValuePromise.setup(promiseValue: promiseValue)
        javascriptValuePromise.then { (value) in
            let converter = JavascriptConverter<T>(value: value)
            if let convertedResult = converter.swiftObject() {
                self.callThen(convertedResult)
            } else {
                self.callExcept(JSBridgeError(type: .jsConversionFailed))
            }
        }
        javascriptValuePromise.except { (error) in
            self.callExcept(error)
        }
    }
    
    public func fail() {
        callExcept(JSBridgeError(type: .jsPromiseFailed))
    }
}

public class JavascriptValuePromise {
    
    private var thenCallback: ((JSValue) -> Void)?
    private var catchCallback: ((JSBridgeError) -> Void)?
    private var isCancelled = false
    
    private var thenValue: JSValue?
    private var exceptValue: JSBridgeError?
    
    private let thenLock = NSLock()
    private let catchLock = NSLock()
    
    public init() {}
    
    @discardableResult public func then(_ callback: @escaping ((JSValue) -> Void)) -> JavascriptValuePromise {
        thenLock.lock()
        if let thenValue = thenValue {
            DispatchQueue.main.async { [weak self] in
                callback(thenValue)
                self?.thenCallback = nil
                self?.catchCallback = nil
            }
        }
        
        thenCallback = callback
        thenLock.unlock()
        return self
    }
    @discardableResult public func except(_ callback: @escaping ((JSBridgeError) -> Void)) -> JavascriptValuePromise {
        catchLock.lock()
        if let exceptValue = exceptValue {
            DispatchQueue.main.async { [weak self] in
                callback(exceptValue)
                self?.thenCallback = nil
                self?.catchCallback = nil
            }
        }
        catchCallback = callback
        catchLock.unlock()
        return self
    }
    public func cancel() {
        isCancelled = true
    }
    
    private func callThen(_ result: JSValue) {
        thenLock.lock()
        if let callback = thenCallback {
            DispatchQueue.main.async { [weak self] in
                callback(result)
                self?.thenCallback = nil
                self?.catchCallback = nil
            }
        } else {
            thenValue = result
        }
        thenLock.unlock()
    }
    
    private func callExcept(_ error: JSBridgeError) {
        catchLock.lock()
        if let callback = catchCallback {
            DispatchQueue.main.async { [weak self] in
                callback(error)
                self?.thenCallback = nil
                self?.catchCallback = nil
            }
        } else {
            exceptValue = error
        }
        catchLock.unlock()
    }
    
    public func setup(promiseValue: JSValue) {
        // We always set then/catch callbacks, even if they're not set by calling client code.
        // The reason behind this is our threading model of JavascriptInterpreter running
        // everything on a serial-bg-queue, so it might happen that when we set them,
        // the promise is already finished.
        
        // Callbacks need to have a strong reference to JavascriptPromise<T>,
        // because noone else does, as client code usually doesn't.
        
        let thenCallback: @convention(block) (JSValue?) -> Void = { (value) in
            if self.isCancelled {
                return
            }
            
            guard let value = value else {
                self.callExcept(JSBridgeError(type: .jsPromiseReturnedNilObj))
                return
            }
            
            self.callThen(value)
        }
        promiseValue.invokeMethod("then", withArguments: [unsafeBitCast(thenCallback, to: AnyObject.self)])
        
        let catchCallback: @convention(block) (JSValue?) -> Void = { (value) in
            if self.isCancelled {
                return
            }
            
            guard let value = value else {
                self.callExcept(JSBridgeError(type: .jsPromiseReturnedNilObj))
                return
            }
            
            self.callExcept(JSBridgeError.from(jsValue: value))
        }
        promiseValue.invokeMethod("catch", withArguments: [unsafeBitCast(catchCallback, to: AnyObject.self)])
    }
    
    public func fail() {
        self.catchCallback?(JSBridgeError(type: .jsPromiseFailed))
    }
}
