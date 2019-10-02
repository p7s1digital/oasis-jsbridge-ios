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

open class JSBridgeError: NSObject, Error {
    public let type: String
    public var code: Int?
    public let message: String
    
    convenience init(type: ErrorType, message: String? = nil) {
        self.init(type: type.rawValue, message: message ?? JSBridgeError.errorTypeToMessage(type))
    }
    
    init(type: String, code: Int? = nil, message: String? = nil) {
        self.type = type
        self.code = code
        self.message = message ?? JSBridgeError.errorTypeToMessage(.unknown)
        super.init()
    }
    
    public enum ErrorType: String {
        case unknown
        case jsError
        case jsEvaluationFailed
        case jsConversionFailed
        case jsFunctionNotFound
        case jsPromiseFailed
        case jsPromiseReturnedNilObj
        case jsonDeserializationFailed
    }
    
    private static func errorTypeToMessage(_ errorType: ErrorType) -> String {
        switch errorType {
        case .unknown:
            return "Unknown error"
        case .jsError:
            return "JS Error"
        case .jsFunctionNotFound:
            return "JS function not found"
        case .jsConversionFailed:
            return "Conversion from JS to Swift object failed"
        case .jsPromiseFailed:
            return "Promise failed"
        case .jsPromiseReturnedNilObj:
            return "Promise returned nil object"
        case .jsonDeserializationFailed:
            return "JSON deserialization failed"
        case .jsEvaluationFailed:
            return "JS evaluation failed"
        }
    }
    
    // Convert JS error to JSBridgeError
    public static func from(jsValue: JSValue?) -> JSBridgeError {
        
        guard let jsValue = jsValue else {
            return JSBridgeError(type: .unknown)
        }
        
        var errorType: String = "unknown"
        var errorCode: Int?
        var errorMessage: String?
        
        if jsValue.hasProperty("type"),
           let type = jsValue.forProperty("type").toString() {
            errorType = type
        }
        if jsValue.hasProperty("code") {
            errorCode = Int(jsValue.forProperty("code").toInt32())
        }
        if jsValue.hasProperty("message"), let message = jsValue.forProperty("message").toString() {
            errorMessage = message
        }
        
        return JSBridgeError(type: errorType, code: errorCode, message: errorMessage)
    }
}
