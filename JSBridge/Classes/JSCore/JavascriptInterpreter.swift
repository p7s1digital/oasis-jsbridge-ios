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

open class JavascriptInterpreter: JavascriptInterpreterProtocol {

    private static let JSQUEUE_LABEL = "JSBridge.JSSerialQueue"
    private static let jsQueueKey = DispatchSpecificKey<String>()

    public var jsContext: JSContext!
    private let jsQueue: DispatchQueue
    private let localStorage:LocalStorage!
    private var urlSession = JavascriptInterpreter.createURLSession()
    private let timeouts: JavascriptTimeouts
    private var xmlHttpRequestInstances = NSPointerArray.weakObjects()
    private var webSocketInstances = NSPointerArray.weakObjects()
    private let sessionStorage = SessionStorage()
    private var lastException: JSValue?
    
    enum JSError: Error {
        case runtimeError(String)
    }

    // MARK: - Initializer
    
    /// - Parameter namespace: A unique prefix string to differenciates different of instances
    public init(namespace:String = "default") {
        
        jsContext = JSContext()!
        
        localStorage = LocalStorage(with: namespace)
        
        jsQueue = DispatchQueue(label: JavascriptInterpreter.JSQUEUE_LABEL)
        jsQueue.setSpecific(key: JavascriptInterpreter.jsQueueKey, value: JavascriptInterpreter.JSQUEUE_LABEL)

        timeouts = JavascriptTimeouts(queue: jsQueue)

        setupExceptionHandling()
        setupGlobal()
        setupConsole()
        setupNativePromise()
        setupStringify()
        setupTimeoutAndInterval()
        setupXMLHttpRequest()
        if #available(iOS 13, tvOS 13, *) {
            setupWebSocket()
        }
        setupLoadURL()
        setupStorage()
    }
    
    // MARK: - Deinit

    deinit {
        Logger.debug("JSCoreJavascriptInterpreter - destroy()")

        xmlHttpRequestInstances.allObjects.forEach({ ($0 as? XMLHttpRequest)?.clearJSValues() })
        xmlHttpRequestInstances = NSPointerArray.weakObjects()
        urlSession.reset { }

        if #available(iOS 13, tvOS 13, *) {
            webSocketInstances.allObjects.forEach({ ($0 as? WebSocket)?.clear() })
            webSocketInstances = NSPointerArray.weakObjects()
        }

        timeouts.clearAll()
        jsContext = nil
    }

    // MARK: - JavascriptInterpreterProtocol

    // bundleIdentifier for JSBridge: de.probiensat1digital.JSBridge
    public func evaluateLocalFile(bundle: Bundle, filename: String, cb: (() -> Void)?) {
        Logger.debug("JSCoreJavascriptInterpreter - evaluateLocalFile(\(filename))")

        guard filename.hasSuffix(".js") && filename.count >= 4 else {
            Logger.error("JS file expected!")
            cb?()
            return
        }

        if filename.hasSuffix(".max.js") {
            let error = JSBridgeError(type: .jsError, message: "Error: .max.js file should not be directly set, use .js in debug mode instead!")
            Logger.error(error.message)
            cb?()
            return
        }

        let basename = String(filename.prefix(filename.count - 3))
        var tryJsPath: String?

        #if DEBUG
        // When debugging, try with a .max.js file first
        let basenameMax = basename + ".max"
        tryJsPath = bundle.path(forResource: basenameMax, ofType: "js")
        if tryJsPath != nil {
            Logger.debug("\(basenameMax).js found in debug mode and will be used instead of \(filename)")
        }
        #endif

        if tryJsPath == nil {
            // In release or when the .max.js file does not exist, directly use the given .js file
            tryJsPath = bundle.path(forResource: basename, ofType: "js")
        }

        guard let jsPath = tryJsPath else {
            Logger.error("Unable to read resource files for \(basename).js.")
            cb?()
            return
        }

        runOnJSQueue { [weak self] in
            do {
                let jsSource = try String(contentsOfFile: jsPath, encoding: String.Encoding.utf8)
                _ = self?.jsContext.evaluateScript(jsSource, withSourceURL: URL(string: jsPath))

            } catch let error {
                Logger.error("Error while processing script file: \(error)")
            }

            cb?()
        }
    }

    public func evaluateString(js: String, cb: ((_: JSValue?, _: JSBridgeError?) -> Void)?) {
        runOnJSQueue { [weak self] in
            guard let self = self else { return }

            self.lastException = nil
            let ret = self.jsContext.evaluateScript(js)

            // Making the call synchronous to make sure that the order is preserved
            if let keepCallback = cb {
                self.runOnMainQueue {
                    if let lastException = self.lastException {
                        let error = JSBridgeError(type: .jsEvaluationFailed, message: lastException.toString())
                        keepCallback(nil, error)
                    } else {
                        keepCallback(ret, nil)
                    }
                }
            }
        }
    }

    @discardableResult
    public func evaluateScript(_ script: String) throws -> JSValue? {
        var result: JSValue?

        runOnJSQueue(synchronous: true) { [self] in
            lastException = nil
            result = jsContext.evaluateScript(script)
        }

        if let lastException {
            throw JSBridgeError(type: .jsEvaluationFailed, message: lastException.toString())
        }

        return result
    }
    
    // MARK: - calling JS functions

    open func call(object: JSValue?,
              functionName: String,
              arguments: [Any],
              completion: @escaping (JSValue?) -> Void) {

        runOnJSQueue { [weak self] in

            guard let strongSelf = self else { return }
            let keepCompletion = completion

            let (object, function) = strongSelf.javascriptFunction(object: object, name: functionName)

            let value = object.invokeMethod(function, withArguments: strongSelf.converted(arguments))
            DispatchQueue.main.async {
                keepCompletion(value)
            }
        }
    }

    open func callSynchronously(object: JSValue?,
              functionName: String,
              arguments: [Any]) -> JSValue {

        var result: JSValue!
        let semaphore = DispatchSemaphore(value: 0)
        runOnJSQueue {
            let (object, function) = self.javascriptFunction(object: object, name: functionName)
            let convertedArguments = self.converted(arguments)
            result = object.invokeMethod(function, withArguments: convertedArguments)
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    public func callWithCallback<T: Codable>(object: JSValue?,
                                      functionName: String,
                                      arguments: [Any],
                                      completion: @escaping (T?) -> Void) {

        call(object: object, functionName: functionName, arguments: converted(arguments)) { (jsValue) in

            guard let jsValue = jsValue else {
                completion(nil)
                return
            }
            let object = JavascriptConverter<T>(value: jsValue).swiftObject()
            completion(object)
        }
    }

    public func callWithPromise<T: Codable>(object: JSValue?,
                                     functionName: String,
                                     arguments: [Any]) -> JavascriptPromise<T> {

        let promise = JavascriptPromise<T>()
        runOnJSQueue(synchronous: true) { [weak self] in

            guard let strongSelf = self else { return }

            let (object, function) = strongSelf.javascriptFunction(object: object, name: functionName)

            guard let value = object.invokeMethod(function, withArguments: strongSelf.converted(arguments)) else {
                promise.fail()
                return
            }
            promise.setup(promiseValue: value)
        }
        return promise
    }

    public func callWithValuePromise(object: JSValue?,
                              functionName: String,
                              arguments: [Any]) -> JavascriptValuePromise {

        let promise = JavascriptValuePromise()
        runOnJSQueue(synchronous: true) { [weak self] in

            guard let strongSelf = self else { return }

            let (object, function) = strongSelf.javascriptFunction(object: object, name: functionName)

            guard let value = object.invokeMethod(function, withArguments: strongSelf.converted(arguments)) else {
                promise.fail()
                return
            }
            promise.setup(promiseValue: value)
        }
        return promise
    }

    public func setObject(_ object: Any!, forKey key: String) {
        jsContext.setObject(object, forKeyedSubscript: key as NSString)
    }

    public func isFunction(object: JSValue?,
                           functionName: String,
                           completion: @escaping (Bool) -> Void) {

        runOnJSQueue {
            let (value, name) = self.javascriptFunction(object: object, name: functionName)
            if value.isUndefined {
                completion(false)
                return
            }

            guard let functionValue = value.objectForKeyedSubscript(name) else {
                completion(false)
                return
            }

            let isDefined = { (value: JSValue, key: String) in
                return !(value.objectForKeyedSubscript(key)?.isUndefined ?? true)
            }

            let isFunction = (!functionValue.isUndefined) &&
                                isDefined(functionValue, "apply") &&
                                isDefined(functionValue, "call")
            completion(isFunction)
        }
    }

    private func javascriptFunction(object: JSValue?, name: String) -> (JSValue, String) {

        var returnObject: JSValue = object ?? jsContext.globalObject
        var nextObject: JSValue = returnObject
        var returnName: String!
        for keyInContext in name.split(separator: ".") {

            returnObject = nextObject
            returnName = String(keyInContext)

            if let object = nextObject.objectForKeyedSubscript(keyInContext), !object.isUndefined {
                nextObject = object
            } else {
                let error = JSBridgeError(type: .jsFunctionNotFound, message: "JS function \(name) not found")
                Logger.error(error.message)
                return (JSValue(undefinedIn: self.jsContext), returnName)
            }
        }
        return (returnObject, returnName)
    }

    // Closures can be passed as argument as well, but for an automatic conversion
    // from JSValue to Codable objects, we need a wrapper class to perform the typed conversion.
    private func converted(_ arguments: [Any]) -> [Any] {
        var converted = [Any]()
        for argument in arguments {
            if let javascriptCallback = argument as? JavascriptCallbackProtocol {
                let callback: @convention(block) (JSValue?, JSValue?) -> Void = { (value, error) in
                    javascriptCallback.onResult(value: value, error: error)
                }
                converted.append(unsafeBitCast(callback, to: AnyObject.self))
            } else {
                converted.append(argument)
            }
        }
        return converted
    }

    /**
     * Find an object in the JSContext by traversing the name by its keys.
     * Please note that this method is supposed to be called from
     * the JS dispatch queue (jsQueue), otherwise the order cannot be
     * guaranteed!
     */
    private func javascriptObject(name: String) -> JSValue? {

        if let object = jsContext.globalObject.objectForKeyedSubscript(name), !object.isUndefined {
            return object
        } else {
            return nil
        }
    }

    // MARK: - Private methods

    func isRunningOnJSQueue() -> Bool {
        return DispatchQueue.getSpecific(key: JavascriptInterpreter.jsQueueKey) == JavascriptInterpreter.JSQUEUE_LABEL
    }

    func runOnJSQueue(synchronous: Bool = false, _ block: @escaping () -> Void) {
        if isRunningOnJSQueue() {
            block()
        } else {
            if synchronous {
                jsQueue.sync(execute: block)
            } else {
                jsQueue.async(execute: block)
            }
        }
    }
    
    private func runOnMainQueue(block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }

    private func setupExceptionHandling() {
        jsContext.exceptionHandler = { [weak self] context, exception in
            self?.lastException = exception

            if let stacktrace = exception?.objectForKeyedSubscript("stack") {
                Logger.error("JS ERROR: \(exception!)\n\(stacktrace)")
            } else if let exception = exception {
                Logger.error("JS ERROR: \(exception)")
            } else {
                Logger.error("UNKNOWN JS ERROR")
            }
        }
    }

    private func setupGlobal() {
        jsContext.evaluateScript("""
            var global = this;
            var window = this;
        """)
    }

    private func setupConsole() {
        consoleHelper(methodName: "log", level: .debug)
        consoleHelper(methodName: "trace", level: .debug)
        consoleHelper(methodName: "info", level: .info)
        consoleHelper(methodName: "warn", level: .warning)
        consoleHelper(methodName: "error", level: .error)
        consoleHelper(methodName: "dir", level: .debug)

        // console.assert(condition, message)
        let consoleAssert: @convention(block) (Bool) -> Void = { condition in
            if condition == true {
                return
            }

            let str = "JS ASSERTION FAILED: " + JSContext.currentArguments()!.suffix(from: 1).map { "\($0)" }.joined(separator: " ")
            Logger.error(str)
        }
        let console = jsContext.objectForKeyedSubscript("console")
        console?.setObject(unsafeBitCast(consoleAssert, to: AnyObject.self), forKeyedSubscript: "assert" as NSString)
    }

    private func consoleHelper(methodName: String, level: JSBridgeLoggingLevel) {
        let consoleFunc: @convention(block) () -> Void = {
            let message = JSContext.currentArguments()!.map { "\($0)"}.joined(separator: " ")
            Logger.log(level: level, message: message)
        }
        let console = jsContext.objectForKeyedSubscript("console")
        console?.setObject(unsafeBitCast(consoleFunc, to: AnyObject.self), forKeyedSubscript: methodName as NSString)
    }

    // MARK: - Promise

    private func setupNativePromise() {
        jsContext.evaluateScript("""
            jsBridgeCreatePromiseWrapper = () => {
              var wrapper = {}
              wrapper.promise = new Promise((resolve, reject) => {
                wrapper.resolve = resolve
                wrapper.reject = reject
              })
              return wrapper
            }
        """)
    }

    private func setupStringify() {
        jsContext.evaluateScript("""
            function __jsBridge__stringify(err) {
              var replaceErrors = function (_key, value) {
                if (value instanceof Error) {
                  // Replace Error instance into plain JS objects using Error own properties
                  return Object.getOwnPropertyNames(value).reduce(function (acc, key) {
                    acc[key] = value[key];
                    return acc;
                  }, {});
                }

                return value;
              };

              return JSON.stringify(err, replaceErrors);
            }
        """)
    }

    // MARK: - Storage

    func setupStorage() {
        jsContext.setObject(localStorage, forKeyedSubscript: "localStorage" as NSString)
        jsContext.setObject(sessionStorage, forKeyedSubscript: "sessionStorage" as NSString)
    }

    // MARK: - Timeout and Interval

    private func setupTimeoutAndInterval() {
        let native = "__jsBridge__timeouts"
        jsContext.setObject(timeouts, forKeyedSubscript: native as NSString)
        jsContext.evaluateScript("""
            function setInterval(callback, ms, ...args) {
              return \(native).setInterval(callback, ms, ...args)
            }
            function setTimeout(callback, ms, ...args) {
              return \(native).setTimeout(callback, ms, ...args)
            }
            function clearTimeout(identifier) {
              \(native).clearTimeout(identifier)
            }
            function clearInterval(identifier) {
              \(native).clearInterval(identifier)
            }
            function setImmediate() {
              console.log(`### setImmediate() NOT IMPLEMENTED`)
            };
        """)
    }

    // MARK: - XMLHttpRequest

    private static func createURLSession() -> URLSession {
        // Disable cache for now
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }

    private func setupXMLHttpRequest() {
        XMLHttpRequest.configure(urlSession: urlSession, jsQueue: jsQueue, context: jsContext, logger: {
            Logger.verbose("XHR: \($0)")
        })
    }
    
    @available(iOS 13, tvOS 13, *)
    private func setupWebSocket() {
        WebSocket.globalInit(withJSQueue: jsQueue)
        WebSocket.extend(jsContext) { [weak self] instance in
            guard let strongSelf = self else {
                instance.clear()
                return
            }
            
            let pointer = Unmanaged.passUnretained(instance).toOpaque()
            strongSelf.webSocketInstances.addPointer(pointer)
        }
    }

    private func setupLoadURL() {
        // loadUrl(url, cb)
        let loadUrl: @convention(block) (String, JSValue?) -> Void = { [weak self] urlString, v in
            Logger.debug("Native loadUrl(\(urlString))")

            guard let strongSelf = self else { return }

            guard let url = URL(string: urlString) else {
                Logger.error("Invalid URL: \(urlString)")
                return
            }

            let task = strongSelf.urlSession.dataTask(with: url) { [weak self] (data, _, error) in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.jsQueue.async {
                    if let error = error {
                        Logger.error(error.localizedDescription)
                        _ = v?.call(withArguments: ["ERROR"])
                        return
                    }

                    guard let data = data else {
                        _ = v?.call(withArguments: ["EMPTY DATA"])
                        return
                    }

                    let str = String(data: data, encoding: .utf8)!
                    _ = strongSelf.jsContext.evaluateScript(str, withSourceURL: url)
                    _ = v?.call(withArguments: [])
                }
            }
            task.resume()
        }
        jsContext.setObject(loadUrl, forKeyedSubscript: "loadUrl" as NSString)
    }
}
