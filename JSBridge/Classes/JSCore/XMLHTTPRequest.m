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

#import "XMLHTTPRequest.h"

static NSURLSession *_urlSession;
static dispatch_queue_t _jsQueue;
static NSPointerArray *_instances = nil;

@implementation XMLHttpRequest {
    NSString *_httpMethod;
    NSURL *_url;
    bool _async;
    bool _isAborted;
    NSMutableDictionary *_requestHeaders;
    NSDictionary *_responseHeaders;
    NSString *_responseType;
};

@synthesize response;
@synthesize responseText;
@synthesize responseType;
@synthesize onreadystatechange;
@synthesize readyState;
@synthesize onload;
@synthesize onabort;
@synthesize onprogress;  // TODO
@synthesize onerror;     // TODO
@synthesize status;
@synthesize statusText;
@synthesize withCredentials;
@synthesize onCompleteHandler;
@synthesize loggingHandler;

+ (void)globalInit {
    [XMLHttpRequest globalInitWithURLSession:[NSURLSession sharedSession] jsQueue:dispatch_get_main_queue()];
}

+ (void)globalInitWithURLSession:(NSURLSession *)urlSession {
    [XMLHttpRequest globalInitWithURLSession:urlSession jsQueue:dispatch_get_main_queue()];
}

+ (void)globalInitWithURLSession:(NSURLSession *)urlSession jsQueue:(dispatch_queue_t)jsQueue {
    _urlSession = urlSession;
    _jsQueue = jsQueue;
}

- init {
    if (self = [super init]) {
        self.readyState = @(XMLHttpRequestUNSENT);
        self.responseType = @"";

        _requestHeaders = [NSMutableDictionary new];

        // Set a default user agent in the form "Apple iPhone iOS 10.0"
        UIDevice *currentDevice = [UIDevice currentDevice];
        NSString *userAgent = [NSString stringWithFormat:@"Apple %@ %@ %@",
                               [currentDevice model], [currentDevice systemName], [currentDevice systemVersion]];

        [_requestHeaders setValue:userAgent forKey:@"User-Agent"];
    }
    return self;
}

+ (void)extend:(id)jsContext onNewInstance:(void(^)(XMLHttpRequest *))onNewInstance {
    dispatch_async(_jsQueue, ^{
        // Simulate the constructor
        jsContext[@"XMLHttpRequest"] = ^{
            XMLHttpRequest *instance = [XMLHttpRequest new];
            onNewInstance(instance);
            return instance;
        };
        jsContext[@"XMLHttpRequest"][@"UNSENT"] = @(XMLHttpRequestUNSENT);
        jsContext[@"XMLHttpRequest"][@"OPENED"] = @(XMLHttpRequestOPENED);
        jsContext[@"XMLHttpRequest"][@"LOADING"] = @(XMLHttpRequestLOADING);
        jsContext[@"XMLHttpRequest"][@"HEADERS"] = @(XMLHttpRequestHEADERS);
        jsContext[@"XMLHttpRequest"][@"DONE"] = @(XMLHttpRequestDONE);
    });
}

- (void)clearJSValues {
    // Null all JSValue instances to avoid a retain cycle causing the JSContext instance to be leaked
    self.onreadystatechange = nil;
    self.onload = nil;
    self.onabort = nil;
    self.onprogress = nil;
    self.onerror = nil;
}

- (void)open:(NSString *)httpMethod :(NSString *)url :(bool)async {
    // TODO should throw an error if called with wrong arguments
    _httpMethod = httpMethod;
    _url = [NSURL URLWithString:url];
    _async = async;
    self.readyState = @(XMLHttpRequestOPENED);
}

- (void)send:(id)data {
    NSURL *url = _url;

    // handle invalid URLs (often no scheme or invalid characters like curly brackets
    // can cause NSURL object not be created in open:
    if (url == nil) {
        [self.onerror callWithArguments:@[]];
        return;
    }

    self.readyState = @(XMLHttpRequestLOADING);
    [self.onreadystatechange callWithArguments:@[]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    for (NSString *name in _requestHeaders) {
        [request setValue:_requestHeaders[name] forHTTPHeaderField:name];
    }
    if ([data isKindOfClass:[NSString class]]) {
        request.HTTPBody = [((NSString *) data) dataUsingEncoding:NSUTF8StringEncoding];
    }
    [request setHTTPMethod:_httpMethod];

    __block __weak XMLHttpRequest *weakSelf = self;
    id completionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        XMLHttpRequest *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }

        dispatch_async(_jsQueue, ^{
            [strongSelf handleResponse:response data:data error:error];
        });
    };

    NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:request completionHandler:completionHandler];
    [task resume];
}

- (void)handleResponse:(NSURLResponse*)receivedResponse data:(NSData*)data error:(NSError*)error {
    if ([self.readyState isEqual:@(XMLHttpRequestUNSENT)]) {
        [self.onabort callWithArguments:@[]];
        return;
    } else if (![self.readyState isEqual:@(XMLHttpRequestLOADING)]) {
        return;
    }

    if (error != nil) {
        [self.onerror callWithArguments:@[]];
        return;
    }

    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)receivedResponse;
    readyState = @(XMLHttpRequestDONE);
    status = @(httpResponse.statusCode);
    statusText = [NSString stringWithFormat:@"%lid", (long)httpResponse.statusCode];
    responseText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    [self setAllResponseHeaders:httpResponse.allHeaderFields];

    self.response = [self getResponseWithResponseType:responseType responseText:responseText];

    [onreadystatechange callWithArguments:@[]];
    [onload callWithArguments:@[]];

    if (loggingHandler) {
        NSString *message = [NSString stringWithFormat:@"[JSBridge] request: %@ response: %ld %@",
                             _url,
                             (long)httpResponse.statusCode,
                             responseText];
        loggingHandler(message);
    }

    // Make sure that the XMLHttpRequest instance can be deallocated by nulling the JSValue instances
    // (which retain the JSContext)
    [self clearJSValues];

    // call onCompleteHandler, required to support Promise on older JSCore versions
    if (onCompleteHandler) onCompleteHandler();

}

- (void)abort {
    // Note: according to the XHR specs, onreadystate() is not supposed to be triggered
    self.readyState = @(XMLHttpRequestUNSENT);
}

- (void)setRequestHeader:(NSString *)name :(NSString *)value {
    _requestHeaders[name] = value;
}

- (NSString *)getAllResponseHeaders {
    NSMutableString *responseHeaders = [NSMutableString new];
    for (NSString *key in _responseHeaders) {
        [responseHeaders appendString:key];
        [responseHeaders appendString:@": "];
        [responseHeaders appendString:_responseHeaders[key]];
        [responseHeaders appendString:@"\r\n"];
    }
    return responseHeaders;
}

- (NSString *)getResponseHeader:(NSString *)name {
    return _responseHeaders[[name lowercaseString]];
}
- (void)setAllResponseHeaders:(NSDictionary *)responseHeaders {
    // Convert to lower case for case-insentive lookup
    NSMutableDictionary *dict = [NSMutableDictionary new];
    [responseHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        NSString *lowerCaseKey = [(NSString *)key lowercaseString];
        dict[lowerCaseKey] = value;
    }];

    _responseHeaders = dict;
}

- (id)getResponseWithResponseType:(NSString * _Nonnull)contentType responseText:(NSString * _Nonnull)responseText {
    if ([contentType isEqualToString:@""]) {
        return responseText;
    }
    
    if ([contentType isEqualToString:@"text"]) {
        return responseText;
    }

    if ([contentType isEqualToString:@"json"]) {
        NSData *data = [responseText dataUsingEncoding:NSUTF8StringEncoding];
        return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    }

    // TODO: support more response types like "arraybuffer", "document"
    return responseText;
}

@end
