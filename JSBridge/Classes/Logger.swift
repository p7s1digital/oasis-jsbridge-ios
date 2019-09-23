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

class Logger {
    
    static var customLogger: JSBridgeLoggingProtocol?
    
    static func log(level: JSBridgeLoggingLevel,
                    message: String,
                    file: StaticString = #file,
                    function: StaticString = #function,
                    line: UInt = #line) {

        if let customLogger = customLogger {
            customLogger.log(level: level, message: message, file: file, function: function, line: line)
        }
    }
    
    static func message(_ message: @autoclosure () -> String,
                        file: StaticString = #file,
                        function: StaticString = #function,
                        line: UInt = #line) {
        log(level: .debug, message: message())
    }
    static func error(_ message: @autoclosure () -> String,
                      file: StaticString = #file,
                      function: StaticString = #function,
                      line: UInt = #line) {
        log(level: .error, message: message())
    }
    static func debug(_ message: @autoclosure () -> String,
                      file: StaticString = #file,
                      function: StaticString = #function,
                      line: UInt = #line) {
        log(level: .debug, message: message())
    }
    static func verbose(_ message: @autoclosure () -> String,
                        file: StaticString = #file,
                        function: StaticString = #function,
                        line: UInt = #line) {
        log(level: .verbose, message: message())
    }
    static func warning(_ message: @autoclosure () -> String,
                        file: StaticString = #file,
                        function: StaticString = #function,
                        line: UInt = #line) {
        log(level: .warning, message: message())
    }
}
