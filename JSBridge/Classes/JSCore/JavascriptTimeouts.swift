import Foundation
import JavaScriptCore

@objc protocol JavascriptTimeoutsExport: JSExport {
    func setInterval(_ callback: JSValue, _ milliseconds: Double) -> String
    func setTimeout(_ callback: JSValue, _ milliseconds: Double) -> String
    func clearTimeout(_ identifier: String)
    func clearInterval(_ identifier: String)
}

/// JavaScript timer functions implementation for JavaScriptCore.
@objc class JavascriptTimeouts: NSObject, JavascriptTimeoutsExport {
    private struct Timeout {
        let id = UUID().uuidString
        let callback: () -> Void
    }

    // MARK: Properties

    private let queue: DispatchQueue
    private var timeouts = [String: Timeout]()

    // MARK: Lifecycle

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func clearAll() {
        queue.async {
            self.timeouts.removeAll()
        }
    }

    // MARK: JavascriptTimeoutsExport

    func setInterval(_ callback: JSValue, _ milliseconds: Double) -> String {
        createTimer(callback: callback, milliseconds: milliseconds, repeats: true)
    }

    func setTimeout(_ callback: JSValue, _ milliseconds: Double) -> String {
        createTimer(callback: callback, milliseconds: milliseconds, repeats: false)
    }

    func clearTimeout(_ identifier: String) {
        invalidateTimer(identifier: identifier)
    }

    func clearInterval(_ identifier: String) {
        invalidateTimer(identifier: identifier)
    }

    // MARK: Helpers

    private func createTimer(callback: JSValue, milliseconds: Double, repeats: Bool) -> String {
        // Get any arguments after code/functionRef and delay
        let arguments = JSContext.currentArguments().map { Array($0.dropFirst(2)) }
        let timeout = Timeout {
            callback.call(withArguments: arguments)
        }

        queue.async(flags: .barrier) {
            self.timeouts[timeout.id] = timeout
        }

        let milliseconds = milliseconds.isNaN ? 0 : Int(milliseconds)
        scheduleTimer(identifier: timeout.id, milliseconds: milliseconds, repeats: repeats)

        return timeout.id
    }

    private func scheduleTimer(identifier: String, milliseconds: Int, repeats: Bool) {
        queue.asyncAfter(deadline: .now() + .milliseconds(milliseconds)) { [weak self] in
            guard let self = self, let timeout = self.timeouts[identifier] else { return }

            Logger.verbose("Timeout \(identifier) triggered")
            timeout.callback()

            if repeats {
                Logger.verbose("Repeating timeout \(identifier)...")
                self.scheduleTimer(identifier: identifier, milliseconds: milliseconds, repeats: repeats)
            } else {
                self.timeouts.removeValue(forKey: identifier)
            }
        }
    }

    private func invalidateTimer(identifier: String) {
        guard identifier != "undefined" else { return }

        queue.async(flags: .barrier) {
            if self.timeouts.removeValue(forKey: identifier) != nil {
                Logger.debug("Aborted timeout with id \(identifier)")
            } else {
                Logger.warning("Cannot abort timeout with id \(identifier): invalid id!")
            }
        }
    }
}
