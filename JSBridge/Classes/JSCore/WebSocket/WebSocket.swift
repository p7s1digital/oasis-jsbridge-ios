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

enum WebSocketState: Int {
    case connecting, open, closing, closed
}

@objc protocol WebSocketProtocol: JSExport {
    var onclose: JSValue? { get set }
    var onerror: JSValue? { get set }
    var onmessage: JSValue? { get set }
    var onopen: JSValue? { get set }
    
    var readyState: Int { get }
    
    func close(_ code: NSNumber?, _ reason: String?)
    func send(_ obj: Any)
}

@objc class WebSocket: NSObject, WebSocketProtocol {
    
    private static weak var jsQueue: DispatchQueue!
    
    var onclose: JSValue?
    var onerror: JSValue?
    var onmessage: JSValue?
    var onopen: JSValue?
    
    private var _readyState: WebSocketState = .connecting
    var readyState: Int { return _readyState.rawValue }
    
    var loggingHandler: ((String) -> Void)?
    
    private var urlSession: URLSession?
    private var socketTask: URLSessionWebSocketTask?
    
    static func globalInit(withJSQueue queue: DispatchQueue) {
        jsQueue = queue
    }

    static func extend(_ jsContext: JSContext, onNewInstance: @escaping (WebSocket) -> Void) {
        jsQueue.async {
            let constr: @convention(block) (String) -> WebSocket? = { (_ urlString: String) in
                guard let instance = try? WebSocket(with: urlString) else {
                    return nil;
                }
                onNewInstance(instance)
                return instance
            }
            
            jsContext.setObject(constr, forKeyedSubscript: "WebSocket" as NSString)
        }
    }
    
    init(with urlString: String) throws {
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
            self?.onerror?.call(withArguments: [err])
        })
    }
    
    private func receive() {
        socketTask?.receive(completionHandler: { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    if let decoded = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) {
                        self?.onmessage?.call(withArguments: [WebSocketMessageEvent(decoded)])
                    }
                case .string(let string):
                    self?.onmessage?.call(withArguments: [WebSocketMessageEvent(string)])
                @unknown default:
                    break
                }
            case .failure(let error):
                self?.onerror?.call(withArguments: [error])
            }
            
            self?.receive()
        })
    }
}

extension WebSocket: URLSessionWebSocketDelegate {
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        _readyState = .open
        onopen?.call(withArguments: [])
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let reasonString = reason != nil ? String(data: reason!, encoding: .utf8) : nil
        let closeEvent = WebSocketCloseEvent(code: closeCode.rawValue, reason: reasonString)
        cleanSession()
        _readyState = .closed
        onclose?.call(withArguments: [closeEvent])
    }
}
