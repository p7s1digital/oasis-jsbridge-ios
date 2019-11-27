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

import UIKit
import JSBridge

class TestLogger: JSBridgeLoggingProtocol {
    func log(level: JSBridgeLoggingLevel, message: String, file: StaticString, function: StaticString, line: UInt) {
        print("[\(level.rawValue)]" + message)
    }
}

class ViewController: UIViewController {
    
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var textView: UITextView!

    var interpreter: JavascriptInterpreter!
    var native: Native?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.text = """
    function fibonacci(num){
        var a = 1, b = 0, temp;
        
        while (num >= 0){
            temp = a;
            a = a + b;
            b = temp;
            num--;
        }
        
        return b;
    }
    
    native.setLabel(fibonacci(100));

    var req = XMLHttpRequest();
    req.open("GET", "https://slashdot.com");
    req.send();
"""
        
        createInterpreter()
    }

    func createInterpreter() {
        
        JSBridgeConfiguration.add(logger: TestLogger())
        interpreter = JavascriptInterpreter()

        native = Native(label: resultLabel)
        interpreter.jsContext.setObject(native, forKeyedSubscript: "native" as NSString)
    }
    
    @IBAction func call() {
        
        let js = textView.text ?? ""
        interpreter.evaluateString(js: js) { (value, error) in
            if let error = error {
                DispatchQueue.main.async {
                    self.resultLabel.text = error.message
                }
            }
        }
    }
}

@objc protocol NativeProtocol: JSExport {
    func setLabel(_ text: String)
}
@objc class Native: NSObject, NativeProtocol {
    let label: UILabel
    init(label: UILabel) {
        self.label = label
    }
    func setLabel(_ text: String) {
        DispatchQueue.main.async {
            self.label.text = text
        }
    }
}
