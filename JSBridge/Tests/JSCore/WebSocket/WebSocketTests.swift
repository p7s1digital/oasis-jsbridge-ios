import Foundation
import Network
import OasisJSBridge
import XCTest

@available(iOS 13, tvOS 13, *)
final class WebSocketTests: XCTestCase {
    private let logger = Logger()
    private let port: NWEndpoint.Port = 12345
    private var listener: NWListener!
    private var connections: [NWConnection] = []

    override func setUpWithError() throws {
        try setupListener()

        JSBridgeConfiguration.add(logger: logger)
    }

    override func tearDownWithError() throws {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.forceCancel() }
        connections.removeAll()

        JSBridgeConfiguration.remove(logger: logger)
    }

    /// https://developer.apple.com/forums/thread/693799?answerId=695452022#695452022
    func setupListener() throws {
        let params = NWParameters.tcp
        let stack = params.defaultProtocolStack
        let ws = NWProtocolWebSocket.Options(.version13)
        stack.applicationProtocols.insert(ws, at: 0)

        listener = try NWListener(using: params, on: port)
        listener.stateUpdateHandler = { newState in
            print("WebSocket listener state changed to '\(newState)'")
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }

            print("WebSocket listener did accept connection \(connection.endpoint)")
            connections.append(connection)
            connection.stateUpdateHandler = { [description = connection.endpoint.debugDescription] newState in
                print("WebSocket connection \(description) state changed to \(newState)")
            }
            connection.start(queue: .main)
            startReceive(connection: connection)
        }
        listener.start(queue: .main)
    }

    private func startReceive(connection: NWConnection) {
        connection.receiveMessage { [weak self, description = connection.endpoint.debugDescription] content, _, _, error in
            guard let self else { return }

            if let error = error {
                print("WebSocket connection \(description) receive failed with error: \(error)")
                return
            }
            if let content = content {
                print("WebSocket connection \(description) received content: '\(String(data: content, encoding: .utf8) ?? "non-UTF8 data of size \(content.count)")'")
            }
            startReceive(connection: connection)
        }
    }

    final class Logger: JSBridgeLoggingProtocol {
        func log(level: OasisJSBridge.JSBridgeLoggingLevel, message: String, file: StaticString, function: StaticString, line: UInt) {
            print("WebSocketTests.Logger: [\(level.rawValue)] \(message)")
        }
    }
}

// MARK: - Tests

@available(iOS 13, tvOS 13, *)
extension WebSocketTests {
    // Verify `WebSocket.onJSQueue` implementation isn't affected by "EXC_BREAKPOINT: retainWeakReference"
    func testWebSocket() async throws {
        var counter = 0
        // Crash has been originally reproduced with the counter in a range of 1...5
        while counter < 13 {
            let interpreter = connectAndSend(id: counter, periodInMilliseconds: 50)
            _ = interpreter // suppress warning
            try await Task.sleep(nanoseconds: NSEC_PER_MSEC * 75)
            counter += 1
        }
    }

    private func connectAndSend(id: Int, periodInMilliseconds: UInt) -> JavascriptInterpreter {
        let interpreter = JavascriptInterpreter(namespace: String(id))
        interpreter.evaluateString(js: """
        let socket = new WebSocket("ws://127.0.0.1:12345/test");
        socket.onopen = function(event) {
          console.log("[\(id)] [open] Connection established");

          setInterval(() => {
            if (socket.bufferedAmount === undefined || socket.bufferedAmount == 0) {
              socket.send(`[\(id)] sent at ${new Date().getTime()} (ms)`);
            }
          }, \(periodInMilliseconds));
        };

        socket.onclose = function(event) {
          console.log(`[\(id)] [close] Connection closed, wasClean=${event.wasClean}, code=${event.code} reason=${event.reason}`);
        };

        socket.onerror = function(error) {
          console.log(`[\(id)] [error] ${error}`);
        };
        """)
        return interpreter
    }
}
