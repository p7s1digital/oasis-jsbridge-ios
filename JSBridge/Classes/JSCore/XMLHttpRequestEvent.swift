import Foundation
import JavaScriptCore

@objc protocol DOMEvent: JSExport {

    var type: String { get }
    var target: XMLHttpRequestJSExport? { get }
    var srcElement: XMLHttpRequestJSExport? { get }
    var currentTarget: XMLHttpRequestJSExport? { get }
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

/// Object for the event, emitted by the XMLHttpRequest
class XMLHttpRequestEvent: NSObject {

    /// https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest#events
    enum EventType: String, CaseIterable {
        case abort
        case error
        case load
        case loadEnd = "loadend"
        case loadStart = "loadstart"
        case progress
        case readyStateChange = "readystatechange"
        case timeout
    }

    var type: String
    var currentTarget: XMLHttpRequestJSExport?
    var target: XMLHttpRequestJSExport?
    var srcElement: XMLHttpRequestJSExport?

    init(type: XMLHttpRequestEvent.EventType, value: XMLHttpRequestJSExport) {
        self.type = type.rawValue
        self.target = value
        currentTarget = value
        srcElement = value
    }

}

// MARK: - DOMEvent

extension XMLHttpRequestEvent: DOMEvent {

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
