import Foundation
import JavaScriptCore
//import Logging

private enum XMLHttpRequestStatus: NSNumber {
    case unsent = 0, opened, headers, loading, done
}

@objc protocol XMLHttpRequestJSExport: JSExport {
    var onload: JSValue? { get set }
    var onsend: JSValue? { get set }
    var onreadystatechange: JSValue? { get set }
    var onabort: JSValue? { get set }
    var onerror: JSValue? { get set }
    var readyState: NSNumber { get set }
    var response: Any? { get set }
    var responseText: String? { get set }
    var responseType: String { get set }
    var status: NSNumber { get set }

    func open(_ httpMethod: String, _ url: String)
    func send(_ data: Any?)
    func abort()
    func setRequestHeader(_ header: String, _ value: String)
    func getAllResponseHeaders() -> String
    func getResponseHeader(_ name: String) -> String?
    func addEventListener(_ type: String, _ handler: JSValue)
    func removeEventListener(_ type: String, _ handler: JSValue)
}

@objc class XMLHttpRequest: NSObject {
    // MARK: Internal properties

    dynamic var readyState = XMLHttpRequestStatus.unsent.rawValue
    dynamic var onload: JSValue?
    dynamic var onsend: JSValue?
    dynamic var onreadystatechange: JSValue?
    dynamic var onabort: JSValue?
    dynamic var onerror: JSValue?
    dynamic var response: Any?
    dynamic var responseText: String?
    dynamic var responseType = ""
    dynamic var status: NSNumber = 0

    // MARK: Private properties

    private let jsQueue: DispatchQueue
    private weak var context: JSContext?

    private var eventListeners = [XMLHttpRequestEvent.EventType: JSValue]()
    private var request: URLRequest?
    private var responseHeaders = [String: String]()
    private var responseHeadersString = ""

    private lazy var urlCharacterSet: CharacterSet = {
        CharacterSet(charactersIn: ";,/?:@&=+$-_.!~*'()%").union(.urlHostAllowed)
    }()

    // MARK: Init

    init(jsQueue: DispatchQueue, context: JSContext) {
        self.jsQueue = jsQueue
        self.context = context

        super.init()
    }

    // MARK: Internal static methods

    static func configure(jsQueue: DispatchQueue, context: JSContext) {
        jsQueue.async {
            let constructor: @convention(block) () -> XMLHttpRequest = {
                XMLHttpRequest(jsQueue: jsQueue, context: context)
            }
            context.setObject(constructor, forKeyedSubscript: NSString(string: "XMLHttpRequest"))

            let xmlRequest = context.objectForKeyedSubscript("XMLHttpRequest")!
            xmlRequest.setObject(XMLHttpRequestStatus.unsent.rawValue, forKeyedSubscript: NSString(string: "UNSENT"))
            xmlRequest.setObject(XMLHttpRequestStatus.opened.rawValue, forKeyedSubscript: NSString(string: "OPENED"))
            xmlRequest.setObject(XMLHttpRequestStatus.loading.rawValue, forKeyedSubscript: NSString(string: "LOADING"))
            xmlRequest.setObject(XMLHttpRequestStatus.headers.rawValue, forKeyedSubscript: NSString(string: "HEADERS_RECEIVED"))
            xmlRequest.setObject(XMLHttpRequestStatus.done.rawValue, forKeyedSubscript: NSString(string: "DONE"))
        }
    }
}

// MARK: - JSExport implementation

extension XMLHttpRequest: XMLHttpRequestJSExport {
    func open(_ httpMethod: String, _ urlString: String) {
//        guard let encodedString = urlString.addingPercentEncoding(withAllowedCharacters: urlCharacterSet),
          guard let url = URL(string: urlString) else {
//            jTrace("Cannot create URL from \(urlString)", type: .error, category: .playerKit)
            emitEvent(type: .error)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        self.request = request

        readyState = XMLHttpRequestStatus.opened.rawValue
        emitEvent(type: .readyStateChange)
    }

    func send(_ data: Any?) {
        guard var request else { return }

        emitEvent(type: .loadStart)

        if let payload = data as? String {
            request.httpBody = payload.data(using: .utf8)
        }

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: config)
        session.dataTask(with: request) { [weak self] data, response, error in
            self?.processResponse(data, response, error)
        }.resume()

        readyState = XMLHttpRequestStatus.loading.rawValue
        emitEvent(type: .readyStateChange)
    }

    func setRequestHeader(_ header: String, _ value: String) {
        request?.setValue(value, forHTTPHeaderField: header)
    }

    func abort() {
        readyState = XMLHttpRequestStatus.unsent.rawValue
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

        let eventPayload = XMLHttpRequestEvent(type: type, value: self, context: context)
        property?.call(withArguments: [eventPayload])
        listener?.call(withArguments: [eventPayload])
    }

    func clearJSValues() {
        onreadystatechange = nil
        onload = nil
        onabort = nil
        onerror = nil
    }

    private func processResponse(_ data: Data?, _ response: URLResponse?, _ error: Error?) {
        guard let response = response as? HTTPURLResponse, error == nil else {
            readyState = XMLHttpRequestStatus.done.rawValue
            emitEvent(type: .readyStateChange)

            emitEvent(type: .error)
            return
        }

        jsQueue.async { [weak self] in
            defer { self?.clearJSValues() }
            guard let self else { return }

            if self.readyState == XMLHttpRequestStatus.unsent.rawValue {
                self.emitEvent(type: .abort)
                return
            }

            self.status = NSNumber(value: response.statusCode)

//            if !response.isInSuccessRange {
//                jTrace("XHR response returned with status code \(response.statusCode) for \"\(String(describing: response.url))\"", type: .warning, category: .playerKit)
//            }

            if let data {
                if self.responseType == "json" {
                    let json = try? JSONSerialization.jsonObject(with: data)
                    self.response = json
                } else {
                    self.responseText = String(data: data, encoding: .utf8)
                    self.response = self.responseText
                }
            }

            for field in response.allHeaderFields {
                guard
                    let key = (field.key as? String)?.lowercased(),
                    let value = field.value as? String else { continue }
                self.responseHeadersString += (key + ": " + value + "\r\n")
                self.responseHeaders[key] = value
            }

            self.readyState = XMLHttpRequestStatus.done.rawValue
            self.emitEvent(type: .readyStateChange)

            self.emitEvent(type: .load)
            self.emitEvent(type: .loadEnd)
        }
    }
}
