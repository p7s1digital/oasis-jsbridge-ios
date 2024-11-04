import XCTest

extension XCTestCase {
    
    func stubRequests(url: String, error: Error? = nil, response: (() -> HTTPResponseStub)?) {
        let url = URL(string: url)!
        HTTPStubs.stub(url: url, error: error, response: response)
    }

    func stubRequests(url: String, jsonResponse: String) {
        stubRequests(url: url.trimmingCharacters(in: .whitespaces), error: nil) {
            HTTPResponseStub(
                data: jsonResponse.data(using: String.Encoding.utf8)!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
    }

    func stubRequests(url: String, textResponse: String) {
        stubRequests(url: url, error: nil) {
            HTTPResponseStub(
                data: textResponse.data(using: String.Encoding.utf8)!,
                statusCode: 200,
                headers: nil
            )
        }
    }
}

