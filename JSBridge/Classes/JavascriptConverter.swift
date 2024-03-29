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

extension JSValue {

    public func jsbridge_json() -> String {

        guard
            let stringifyFunction = self.context.globalObject.objectForKeyedSubscript("__jsBridge__stringify"),
            let jsonString = stringifyFunction.call(withArguments: [self]).toString()
            else { return "nil" }
        return jsonString
    }

    @available(*, deprecated, message: "Renamed to jsbridge_toNSDictionary")
    public func convertToDict() -> NSDictionary? {
        return jsbridge_toNSDictionary()
    }

    public func jsbridge_toNSDictionary() -> NSDictionary? {
        do {
            guard let data = self.jsbridge_json().data(using: .utf8),
                let json = try JSONSerialization.jsonObject(with: data) as? NSDictionary else {
                    return nil
            }
            return json
        } catch {
            return nil
        }
    }
    public func jsbridge_toDictionary() -> [String: Any]? {
        do {
            guard let data = self.jsbridge_json().data(using: .utf8),
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return nil
            }
            return json
        } catch {
            return nil
        }
    }
}

public class JavascriptConverter<T: Codable> {

    let obj: T?

    public init(value: JSValue) {
        self.obj = type(of: self).convert(value: value)
    }

    public func swiftObject() -> T? {
        return obj
    }

    private static func convert(value: JSValue) -> T? {

        // we use JSCore to convert the JSValue to JSON string
        guard let stringifyFunction = value.context.globalObject.objectForKeyedSubscript("__jsBridge__stringify")
            else { return nil }

        guard let jsonString = stringifyFunction.call(withArguments: [value]).toString(),
            let jsonData = jsonString.data(using: .utf8)
            else { return nil }

        // convert JSON to Swift class
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: jsonData)
        } catch let error {
            Logger.error("JavascriptCallback \(error)")
        }

        return nil
    }
}
