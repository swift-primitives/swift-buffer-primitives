extension Buffer.Ring: ExpressibleByArrayLiteral where Element: Copyable {
    // running on this function, avoiding a compiler bug in the SIL ownership
    // verifier for @_rawLayout-adjacent types under -O.
    @inlinable
    public init(arrayLiteral elements: Element...) {
        var buffer = Self(minimumCapacity: .init(Cardinal(UInt(elements.count))))
        for element in elements {
            buffer.push.back(element)
        }
        self = buffer
    }
}
