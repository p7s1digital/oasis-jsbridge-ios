import Foundation
import JavaScriptCore

enum EventHandlerEventType: String {
    case loadStart = "loadstart"
    case progress
    case abort
    case error
    case load
    case timeout
    case loadEnd = "loadend"
    case readyStateChange = "readystatechange"
}

@objc protocol EventPayloadProtocol {
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

// MARK: - Object for the event, emitted by the XMLHTTPRequest

class EventPayload: NSObject {
    var type: String
    var currentTarget: JSValue?
    var target: JSValue?
    var srcElement: JSValue?

    init(type: String, target: JSValue?) {
        self.type = type
        self.target = target
        currentTarget = target
        srcElement = target
    }

    init(type: EventHandlerEventType, value: XMLHttpRequestJSExport) {
        self.type = type.rawValue

        let target = EventPayload.createTarget(from: value)
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

extension EventPayload {
    static func createTarget(from value: XMLHttpRequestJSExport) -> JSValue? {
        guard let context = JSContext.current() else { return nil }

        let xhr = context.objectForKeyedSubscript("XMLHttpRequest")
        return xhr ?? JSValue(object: value, in: context)
    }
}
