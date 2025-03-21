import Foundation
import JavaScriptCore

/// https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest
/// https://xhr.spec.whatwg.org/#interface-xmlhttprequest
@objc protocol XMLHttpRequestJSExport: JSExport {
    // Instance properties

    var readyState: NSNumber { get set }
    var response: Any? { get set }
    var responseText: String? { get set }
    var responseType: String { get set }
    var status: NSNumber { get set }

    // Events

    // https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest#events
    var onreadystatechange: JSValue? { get set }
    var onload: JSValue? { get set }
    var onsend: JSValue? { get set }
    var onabort: JSValue? { get set }
    var onerror: JSValue? { get set }

    /// https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener
    func addEventListener(_ type: String, _ handler: JSValue)
    /// https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/removeEventListener
    func removeEventListener(_ type: String, _ handler: JSValue)

    // Instance methods

    func open(_ httpMethod: String, _ url: String)
    func send(_ data: Any?)
    func abort()
    func setRequestHeader(_ header: String, _ value: String)
    func getAllResponseHeaders() -> String
    func getResponseHeader(_ name: String) -> String?
}

/**
 Native implementation of XMLHttpRequest object to request data from a server.
 It is available out-of-the-box in all modern browsers and in WebKit, but not available in JavaScriptCore.

 Limitations of the native implementation:
 - Only a limited set of event callback properties is available, but all event listener events are available.
 - Only the first event listener registered for each event type will be called.
 - Requests cannot be reused. To avoid capturing `JSContext`, all request callbacks and listeners are removed after handling the response.
 */
@objc class XMLHttpRequest: NSObject {
    /// https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest/readyState
    enum ReadyState: NSNumber {
        case unsent = 0, opened, headersReceived, loading, done
    }

    // MARK: Internal properties

    dynamic var readyState = ReadyState.unsent.rawValue
    dynamic var response: Any?
    dynamic var responseText: String?
    dynamic var responseType = ""
    dynamic var status: NSNumber = 0

    dynamic var onreadystatechange: JSValue?
    dynamic var onload: JSValue?
    dynamic var onsend: JSValue?
    dynamic var onabort: JSValue?
    dynamic var onerror: JSValue?

    // MARK: Private properties

    private let jsQueue: DispatchQueue
    private let urlSession: URLSession
    private let logger: ((String) -> Void)?
    private var eventListeners = [XMLHttpRequestEvent.EventType: JSValue]()

    private var request: URLRequest?
    private var dataTask: URLSessionDataTask?
    private var responseHeaders = [String: String]()
    private var responseHeadersString = ""

    // MARK: Init

    init(urlSession: URLSession, jsQueue: DispatchQueue, logger: ((String) -> Void)?) {
        self.urlSession = urlSession
        self.jsQueue = jsQueue
        self.logger = logger

        super.init()
    }

    // MARK: Internal static methods

    static func configure(
        urlSession: URLSession,
        jsQueue: DispatchQueue,
        context: JSContext,
        logger: ((String) -> Void)? = nil
    ) {
        jsQueue.async {
            let constructor: @convention(block) () -> XMLHttpRequest = {
                XMLHttpRequest(urlSession: urlSession, jsQueue: jsQueue, logger: logger)
            }
            context.setObject(constructor, forKeyedSubscript: NSString(string: "XMLHttpRequest"))

            let xmlRequest = context.objectForKeyedSubscript("XMLHttpRequest")!
            xmlRequest.setObject(ReadyState.unsent.rawValue, forKeyedSubscript: NSString(string: "UNSENT"))
            xmlRequest.setObject(ReadyState.opened.rawValue, forKeyedSubscript: NSString(string: "OPENED"))
            xmlRequest.setObject(ReadyState.loading.rawValue, forKeyedSubscript: NSString(string: "LOADING"))
            xmlRequest.setObject(ReadyState.headersReceived.rawValue, forKeyedSubscript: NSString(string: "HEADERS_RECEIVED"))
            xmlRequest.setObject(ReadyState.done.rawValue, forKeyedSubscript: NSString(string: "DONE"))
        }
    }
}

// MARK: - JSExport implementation

extension XMLHttpRequest: XMLHttpRequestJSExport {
    func open(_ httpMethod: String, _ urlString: String) {
        if let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)) {
            var request = URLRequest(url: url)
            request.httpMethod = httpMethod
            self.request = request
        } else {
            log("Cannot create URL from \(urlString)")
            self.request = nil
        }

        readyState = ReadyState.opened.rawValue
        emitEvent(type: .readyStateChange)
    }

    func send(_ data: Any?) {
        // DOMException: Failed to execute 'send' on 'XMLHttpRequest': The object's state must be OPENED.
        guard readyState == ReadyState.opened.rawValue else {
            log("Failed to execute 'send' on 'XMLHttpRequest': The object's state must be \(ReadyState.opened.rawValue) (OPENED), but it is \(readyState)")
            return
        }

        emitEvent(type: .loadStart)

        // Requests created with invalid URL shall fail.
        guard var request else {
            finishWithError()
            return
        }

        if let payload = data as? String {
            request.httpBody = payload.data(using: .utf8)
        }

        let dataTask = urlSession.dataTask(with: request) { [weak self] data, response, error in
            self?.jsQueue.async {
                self?.processResponse(data, response, error)
            }
        }
        self.dataTask = dataTask
        dataTask.resume()
    }

    func setRequestHeader(_ header: String, _ value: String) {
        request?.setValue(value, forHTTPHeaderField: header)
    }

    func abort() {
        if let dataTask {
            dataTask.cancel()
            self.dataTask = nil

            readyState = ReadyState.done.rawValue
            emitEvent(type: .readyStateChange)

            emitEvent(type: .abort)
            emitEvent(type: .loadEnd)
        }

        readyState = ReadyState.unsent.rawValue
        status = 0
    }

    func getAllResponseHeaders() -> String {
        responseHeadersString
    }

    func getResponseHeader(_ name: String) -> String? {
        responseHeaders[name.lowercased()]
    }

    func addEventListener(_ type: String, _ handler: JSValue) {
        guard let eventType = XMLHttpRequestEvent.EventType(rawValue: type), eventListeners[eventType] == nil else { return }

        eventListeners[eventType] = handler
    }

    func removeEventListener(_ type: String, _ handler: JSValue) {
        guard let eventType = XMLHttpRequestEvent.EventType(rawValue: type) else { return }

        eventListeners[eventType] = nil
    }

    // MARK: Private methods

    private func log(_ message: String) {
        logger?(message)
    }

    /// Links XHR Event Type to property callbacks
    private func eventProperty(eventType: XMLHttpRequestEvent.EventType) -> JSValue? {
        switch eventType {
        case .abort:
            return onabort
        case .error:
            return onerror
        case .load:
            return onload
        case .loadStart:
            return onsend
        case .readyStateChange:
            return onreadystatechange
        default:
            return nil
        }
    }

    private func emitEvent(type: XMLHttpRequestEvent.EventType) {
        let property = eventProperty(eventType: type)
        let listener = eventListeners[type]

        // Skip creating event payload if there are no callbacks for given eventType
        guard property != nil || listener != nil else { return }

        let eventPayload = XMLHttpRequestEvent(type: type, value: self)
        property?.call(withArguments: [eventPayload])
        listener?.call(withArguments: [eventPayload])
    }

    /// Nullifies all JSValue instances to avoid a retain cycle causing the JSContext instance to be leaked
    func clearJSValues() {
        onreadystatechange = nil
        onload = nil
        onsend = nil
        onabort = nil
        onerror = nil

        eventListeners.removeAll()
    }

    /// Performs a chain of actions which happens when XHR
    ///   - has been opened and sent with invalid/broken URL;
    ///   - fails with a network error.
    private func finishWithError() {
        readyState = ReadyState.done.rawValue
        emitEvent(type: .readyStateChange)

        emitEvent(type: .error)
        emitEvent(type: .loadEnd)
    }

    private func processResponse(_ data: Data?, _ response: URLResponse?, _ error: Error?) {
        defer { clearJSValues() }

        if let error = error as? NSError, error.domain == NSURLErrorDomain, error.code == NSURLErrorCancelled {
            return
        }

        guard let response = response as? HTTPURLResponse, error == nil else {
            finishWithError()
            return
        }

        if !(200 ..< 300 ~= response.statusCode) {
            log("XHR response returned with status code \(response.statusCode) for \"\(String(describing: response.url))\"")
        }

        status = NSNumber(value: response.statusCode)
        decodeResponse(data: data, responseType: responseType)

        for field in response.allHeaderFields {
            guard
                let key = (field.key as? String)?.lowercased(),
                let value = field.value as? String else { continue }
            responseHeadersString += (key + ": " + value + "\r\n")
            responseHeaders[key] = value
        }

        readyState = ReadyState.headersReceived.rawValue
        emitEvent(type: .readyStateChange)

        readyState = ReadyState.loading.rawValue
        emitEvent(type: .readyStateChange)

        emitEvent(type: .progress)

        readyState = ReadyState.done.rawValue
        emitEvent(type: .readyStateChange)

        emitEvent(type: .load)
        emitEvent(type: .loadEnd)
    }

    private func decodeResponse(data: Data?, responseType: String) {
        // Reset fields state
        responseText = nil
        response = nil

        guard let data else { return }

        switch responseType {
        case "json":
            response = try? JSONSerialization.jsonObject(with: data)
        default:
            responseText = String(data: data, encoding: .utf8)
            response = responseText
        }
    }
}
