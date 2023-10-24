import Foundation
import XCTest

final class HTTPStubsTests: XCTestCase {
    
    var testSession: URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [
            HTTPStubs.self
        ]
        return URLSession(configuration: configuration)
    }
    
    let testUrl = URL(string: "https://jsb_test.testurl/api/request")!
    
    override class func setUp() {
        HTTPStubs.startInterceptingRequests()
    }

    override class func tearDown() {
        HTTPStubs.stopInterceptingRequests()
    }
}

extension HTTPStubsTests {
    func testDefaultSessionIsNotIntercepted() {
        // GIVEN
        HTTPStubs.stopInterceptingRequests() // "undo" setUp() settings
        
        // WHEN
        let expectation = self.expectation(description: "urlRequest")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1
        
        URLSession.shared.dataTask(with: URLRequest(url: testUrl)) { data, response, error in
            // THEN
            XCTAssertNil(response)
            XCTAssertNil(data)
            XCTAssertNotNil(error)
            expectation.fulfill()
        }.resume()
        
        waitForExpectations(timeout: 2)
    }
    
    func testCustomSessionIsIntercepted() {
        // GIVEN
        HTTPStubs.stub(url: testUrl) {
            HTTPResponseStub(
                data: Data(),
                statusCode: 200
            )
        }
        
        // WHEN
        let expectation = self.expectation(description: "urlRequest")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1
        
        testSession.dataTask(with: URLRequest(url: testUrl)) { data, response, error in
            // THEN
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)
            XCTAssert(data?.isEmpty == true)
            XCTAssertNil(error)
            expectation.fulfill()
        }.resume()
        
        waitForExpectations(timeout: 1)
    }
    
    func testResponseDataIsForwarded() {
        // GIVEN
        let initialText = "testData"
        let dataToForward = initialText.data(using: String.Encoding.utf8)!
        HTTPStubs.stub(url: testUrl) {
            HTTPResponseStub(
                data: dataToForward,
                statusCode: 200
            )
        }
        
        // WHEN
        let expectation = self.expectation(description: "urlRequest")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1
        
        testSession.dataTask(with: URLRequest(url: testUrl)) { data, response, error in
            // THEN
            XCTAssertNotNil(response)
            XCTAssertNotNil(data)
            XCTAssertEqual(data, dataToForward)
            let decodedText = String(data: data!, encoding: .utf8)
            XCTAssertNotNil(decodedText)
            XCTAssertEqual(decodedText, initialText)
            XCTAssertNil(error)
            expectation.fulfill()
        }.resume()
        
        waitForExpectations(timeout: 1)
    }
    
    func testResponseCodeIsForwarded() {
        // GIVEN
        HTTPStubs.stub(url: testUrl) {
            HTTPResponseStub(
                data: Data(),
                statusCode: 100
            )
        }
        
        // WHEN
        let expectation = self.expectation(description: "urlRequest")
        expectation.assertForOverFulfill = true
        expectation.expectedFulfillmentCount = 1
        
        testSession.dataTask(with: URLRequest(url: testUrl)) { data, response, error in
            // THEN
            let httpResponse = response as? HTTPURLResponse
            XCTAssertNotNil(httpResponse)
            XCTAssertEqual(httpResponse!.statusCode, 100)
            XCTAssertNotNil(data)
            XCTAssertNil(error)
            expectation.fulfill()
        }.resume()
        
        waitForExpectations(timeout: 1)
    }
}
