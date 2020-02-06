//
//  NativePromise.swift
//  OasisJSBridge
//
//  Created by Michal Bencur on 04.02.20.
//

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

        let semaphore = DispatchSemaphore(value: 0)

        var promiseWrapper: JSValue?
        interpreter.call(functionName: "jsBridgeCreatePromiseWrapper", arguments: []) { (wrapper) in
            promiseWrapper = wrapper
            semaphore.signal()
        }

        semaphore.wait()

        self.promiseWrapper = promiseWrapper
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
