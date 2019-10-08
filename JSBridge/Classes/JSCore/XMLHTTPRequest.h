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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <JavaScriptCore/JavaScriptCore.h>

// Inspired by https://github.com/Lukas-Stuehrk/XMLHTTPRequest/tree/master/XMLHTTPRequest

typedef NS_ENUM(NSUInteger , ReadyState) {
    XMLHttpRequestUNSENT=0,     // open() has not been called yet.
    XMLHttpRequestOPENED,       // send() has not been called yet.
    XMLHttpRequestHEADERS,      // RECEIVED    send() has been called, and headers and status are available.
    XMLHttpRequestLOADING,      // Downloading; responseText holds partial data.
    XMLHttpRequestDONE          // The operation is complete.
};


@protocol XMLHttpRequest <JSExport>

@property (nullable, nonatomic) id response;
@property (nullable, nonatomic) NSString *responseText;
@property (nullable, nonatomic) NSString *responseType;
@property (nullable, nonatomic) JSValue *onreadystatechange;
@property (nullable, nonatomic) NSNumber *readyState;
@property (nullable, nonatomic) JSValue *onload;
@property (nullable, nonatomic) JSValue *onabort;
@property (nullable, nonatomic) JSValue *onprogress;
@property (nullable, nonatomic) JSValue *onerror;
@property (nullable, nonatomic) NSNumber *status;
@property (nullable, nonatomic) NSString *statusText;
@property (nullable, nonatomic) NSString *withCredentials;
@property (nullable, nonatomic, copy) void (^onCompleteHandler)(void);

-(void)clearJSValues;
-(void)open:(nonnull NSString *)httpMethod :(nonnull NSString *)url :(bool)async;
-(void)send:(nonnull id)data;
-(void)abort;
-(void)setRequestHeader:(nonnull NSString *)name :(nonnull NSString *)value;
-(nonnull NSString *)getAllResponseHeaders;
-(nullable NSString *)getResponseHeader:(nonnull NSString *)name;

@end


@interface XMLHttpRequest : NSObject <XMLHttpRequest>

@property (nullable, nonatomic, copy) void (^loggingHandler)(NSString*_Nonnull);

+ (void)globalInit;
+ (void)globalInitWithURLSession:(nonnull NSURLSession*)urlSession;
+ (void)globalInitWithURLSession:(nonnull NSURLSession*)urlSession jsQueue:(nonnull dispatch_queue_t)jsQueue;
+ (void)extend:(nonnull JSContext*)jsContext onNewInstance:(nonnull void(^)(XMLHttpRequest * _Nonnull))onNewInstance;

@end
