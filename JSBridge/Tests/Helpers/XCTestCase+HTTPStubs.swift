import XCTest
import OHHTTPStubs
#if SWIFT_PACKAGE
import OHHTTPStubsSwift
#endif

extension XCTestCase {
    func stubRequests(url: String, response: @escaping () -> HTTPStubsResponse) {
        HTTPStubs.stubRequests(passingTest: isAbsoluteURLString(url)) { _ in
            response()
        }
    }

    func stubRequests(url: String, jsonResponse: String) {
        stubRequests(url: url) {
            HTTPStubsResponse(
                data: jsonResponse.data(using: String.Encoding.utf8)!,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        }
    }

    func stubRequests(url: String, textResponse: String) {
        stubRequests(url: url) {
            HTTPStubsResponse(
                data: textResponse.data(using: String.Encoding.utf8)!,
                statusCode: 200,
                headers: nil
            )
        }
    }
}
