import Foundation

#if !SWIFT_PACKAGE
extension Bundle {
    static var module: Bundle {
        Bundle(for: Native.self)
    }
}
#endif
