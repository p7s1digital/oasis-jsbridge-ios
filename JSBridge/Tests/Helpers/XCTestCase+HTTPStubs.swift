import XCTest

extension XCTestCase {
    
    func stubRequests(url: String, response: @escaping () -> HTTPResponseStub?) {
        let url = URL(string: url)!
        HTTPStubs.stub(url: url, response: response)
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

