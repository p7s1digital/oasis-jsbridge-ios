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

@available(iOS 13, tvOS 13, *)
enum WebSocketState: Int {
    case connecting, open, closing, closed
}

@available(iOS 13, tvOS 13, *)
@objc protocol WebSocketProtocol: JSExport {
    var onclose: JSValue? { get set }
    var onerror: JSValue? { get set }
    var onmessage: JSValue? { get set }
    var onopen: JSValue? { get set }
    
    var readyState: Int { get }
    
    func close(_ code: NSNumber?, _ reason: String?)
    func send(_ obj: Any)
}

@available(iOS 13, tvOS 13, *)
@objc class WebSocket: NSObject, WebSocketProtocol {
    var onclose: JSValue?
    var onerror: JSValue?
    var onmessage: JSValue?
    var onopen: JSValue?
    
    private var _readyState: WebSocketState = .connecting
    var readyState: Int { return _readyState.rawValue }
    
    private weak var jsQueue: DispatchQueue?
    private var urlSession: URLSession?
    private var socketTask: URLSessionWebSocketTask?

    static func polyfill(_ jsContext: JSContext, jsQueue: DispatchQueue, onNewInstance: @escaping (WebSocket) -> Void) {
        jsQueue.async {
            let constructor: @convention(block) (String) -> WebSocket? = { urlString in
                guard let instance = try? WebSocket(with: urlString, jsQueue: jsQueue) else {
                    return nil
                }
                onNewInstance(instance)
                return instance
            }

            jsContext.setObject(constructor, forKeyedSubscript: "WebSocket" as NSString)
        }
    }
    
    init(with urlString: String, jsQueue: DispatchQueue) throws {
        self.jsQueue = jsQueue

        super.init()

        guard let url = URL(string: urlString) else { throw URLError(URLError.Code.badURL) }
        urlSession = URLSession(configuration: URLSessionConfiguration.default,
                                delegate: self,
                                delegateQueue: nil)
        let task = urlSession?.webSocketTask(with: url)
        socketTask = task
        self.receive()
        task?.resume()
    }
    
    private func onJSQueue(_ block: @escaping () -> Void) {
        jsQueue?.async {
            block()
        }
    }
    
    func clear() {
        onclose = nil
        onerror = nil
        onmessage = nil
        onopen = nil
        cleanSession()
    }
    
    private func cleanSession() {
        socketTask?.cancel()
        urlSession?.finishTasksAndInvalidate()
        urlSession = nil
        socketTask = nil
    }
    
    func close(_ code: NSNumber?, _ reason: String?) {
        var closeCode: URLSessionWebSocketTask.CloseCode?
        if let theCode = code {
            closeCode = URLSessionWebSocketTask.CloseCode(rawValue: theCode.intValue)
        }
        if closeCode == nil {
            closeCode = URLSessionWebSocketTask.CloseCode.goingAway
        }
        _readyState = .closing
        socketTask?.cancel(with: closeCode!, reason: reason?.data(using: .utf8))
        cleanSession()
        _readyState = .closed
    }
    
    func send(_ obj: Any) {
        if let string = obj as? String {
            send(string: string)
        } else if let data = obj as? Data {
            send(data: data)
        } else if let json = try? JSONSerialization.data(withJSONObject: obj, options: [.fragmentsAllowed]) {
            send(data: json)
        } else {
            return
        }
    }
    
    private func send(string: String) {
        send(message: URLSessionWebSocketTask.Message.string(string))
    }
    
    private func send(data: Data) {
        send(message: URLSessionWebSocketTask.Message.data(data))
    }
    
    private func send(message: URLSessionWebSocketTask.Message) {
        socketTask?.send(message, completionHandler: { [weak self] error in
            guard let err = error else { return }
            self?.closeWithError(err)
        })
    }
    
    private func closeWithError(_ error: Error) {
        cleanSession()
        _readyState = .closed
        onJSQueue { [weak self] in
            let closeEvent = WebSocketCloseEvent(code: URLSessionWebSocketTask.CloseCode.abnormalClosure.rawValue, reason: nil)
            self?.onclose?.call(withArguments: [closeEvent])
            self?.onerror?.call(withArguments: [error])
        }
    }
    
    private func receive() {
        socketTask?.receive(completionHandler: { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    if let decoded = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                        self?.onJSQueue { [weak self] in
                            self?.onmessage?.call(withArguments: [WebSocketMessageEvent(decoded)])
                        }
                    }
                case .string(let string):
                    self?.onJSQueue { [weak self] in
                        self?.onmessage?.call(withArguments: [WebSocketMessageEvent(string)])
                    }
                @unknown default:
                    break
                }
                self?.receive()
            case .failure(let error):
                self?.closeWithError(error)
            }
        })
    }
}

@available(iOS 13, tvOS 13, *)
extension WebSocket: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        _readyState = .open
        onJSQueue { [weak self] in
            self?.onopen?.call(withArguments: [])
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason != nil ? String(data: reason!, encoding: .utf8) : nil
        let closeEvent = WebSocketCloseEvent(code: closeCode.rawValue, reason: reasonString)
        cleanSession()
        _readyState = .closed
        onJSQueue { [weak self] in
            self?.onclose?.call(withArguments: [closeEvent])
        }
    }
}
