import XCTest

extension XCTestCase {
    
    var testSession: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [
            HTTPStubs.self
        ]
        return URLSession(configuration: configuration)
    }
    
    func stubRequests(url: String, response: @escaping () -> HTTPResponseStub?) {
        let url = URL(string: url)!
        let error = NSError(domain: "any error", code: 1)
        HTTPStubs.stub(url: url, response: response, error: error)
    }

    func stubRequests(url: String, jsonResponse: String) {
        stubRequests(url: url) {
            HTTPResponseStub(
                data: jsonResponse.data(using: String.Encoding.utf8)!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
    }

    func stubRequests(url: String, textResponse: String) {
        stubRequests(url: url) {
            HTTPResponseStub(
                data: textResponse.data(using: String.Encoding.utf8)!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
    }
}

