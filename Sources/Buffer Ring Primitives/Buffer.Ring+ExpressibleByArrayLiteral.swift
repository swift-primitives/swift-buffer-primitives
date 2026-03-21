extension Buffer.Ring: ExpressibleByArrayLiteral where Element: Copyable {
    // WORKAROUND: @_optimize(none) prevents CopyPropagation SIL pass from
    // running on this function, avoiding a compiler bug in the SIL ownership
    // verifier for @_rawLayout-adjacent types under -O.
    // WHEN TO REMOVE: When swiftlang/swift fixes the SIL ownership verifier.
    // TRACKING: Research/release-mode-llvm-verifier-crash-diagnosis.md
    @_optimize(none)
    @inlinable
    public init(arrayLiteral elements: Element...) {
        var buffer = Self(minimumCapacity: .init(Cardinal(UInt(elements.count))))
        for element in elements {
            buffer.push.back(element)
        }
        self = buffer
    }
}
