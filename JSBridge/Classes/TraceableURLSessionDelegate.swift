import Foundation

/// Custom `URLSessionDelegate` which gets swizzled by Datadog to enable end-to-end APM (Tracing).
///
/// - SeeAlso: https://docs.datadoghq.com/tracing/trace_collection/automatic_instrumentation/dd_libraries/ios/?tab=swiftpackagemanagerspm
public class TraceableURLSessionDelegate: NSObject, URLSessionDataDelegate {}
