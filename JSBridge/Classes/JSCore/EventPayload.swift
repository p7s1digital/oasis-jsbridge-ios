import Foundation
import JavaScriptCore

enum EventHandlerEventType: String, CaseIterable {
    case loadStart = "loadstart"
    case progress
    case abort
    case error
    case load
    case timeout
    case loadEnd = "loadend"
    case readyStateChange = "readystatechange"
}

@objc protocol EventPayloadProtocol: JSExport {
    var type: String { get }
    var target: JSValue? { get }
    var srcElement: JSValue? { get }
    var currentTarget: JSValue? { get }
    var composedPath: [Any] { get }

    var eventPhase: Int { get }

    var stopPropagation: (() -> Void) { get }
    var cancelBubble: Bool { get }
    var stopImmediatePropagation: (() -> Void) { get }

    var bubbles: Bool { get }
    var cancelable: Bool { get }
    var returnValue: Bool { get }
    var preventDefault: (() -> Void) { get }

    var defaultPrevented: Bool { get }
    var composed: Bool { get }

    var isTrusted: Bool { get }
    var timeStamp: Int { get }
}

/// Object for the event, emitted by the XMLHTTPRequest
class EventPayload: NSObject {
    var type: String
    var currentTarget: JSValue?
    var target: JSValue?
    var srcElement: JSValue?

    init(type: EventHandlerEventType, value: XMLHttpRequestJSExport) {
        let target = JSContext.current().flatMap { JSValue(object: value, in: $0) }

        self.type = type.rawValue
        self.target = target
        currentTarget = target
        srcElement = target
    }
}

// MARK: - EventPayloadProtocol

extension EventPayload: EventPayloadProtocol {
    var stopPropagation: (() -> Void) { {} }
    var stopImmediatePropagation: (() -> Void) { {} }
    var preventDefault: (() -> Void) { {} }
    var composedPath: [Any] { [] }
    var cancelBubble: Bool { false }
    var bubbles: Bool { false }
    var cancelable: Bool { false }
    var composed: Bool { false }
    var defaultPrevented: Bool { false }
    var eventPhase: Int { 0 }
    var isTrusted: Bool { true }
    var lengthComputable: Bool { false }
    var returnValue: Bool { true }
    var timeStamp: Int { 0 }
}
