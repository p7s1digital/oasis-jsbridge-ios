import Foundation

class HTTPResponseStub {
    var data: Data
    var statusCode: Int
    var headers: [String : String]?
    
    init(data: Data = Data(), statusCode: Int, headers: [String : String]? = nil) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }
}

class HTTPStubs: URLProtocol {
    private static var stubs = [URL: Stub]()

    private struct Stub {
        let response: (() -> HTTPResponseStub)?
        let error: Error?
    }

    static func stub(url: URL, error: Error? = nil, response: (() -> HTTPResponseStub)?) {
        stubs[url] = Stub(response: response, error: error)
    }

    static func startInterceptingRequests() {
        URLProtocol.registerClass(HTTPStubs.self)
    }

    static func stopInterceptingRequests() {
        URLProtocol.unregisterClass(HTTPStubs.self)
        removeAllStubs()
    }
    
    static func removeAllStubs() {
        stubs = [:]
    }
    
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }
    
    override class func canInit(with task: URLSessionTask) -> Bool {
        guard let url = task.originalRequest?.url else {
            return false
        }
        return HTTPStubs.stubs[url] != nil
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else {
            return false
        }
        return HTTPStubs.stubs[url] != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let url = request.url, let stub = HTTPStubs.stubs[url] else {
            return
        }
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else if let response = stub.response?() {
            let httpResponse = HTTPURLResponse(url: url, statusCode: response.statusCode, httpVersion: nil, headerFields: response.headers)!
            client?.urlProtocol(self, didLoad: response.data)
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() { }
}
