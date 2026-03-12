extension Buffer.Ring: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        var buffer = Self(minimumCapacity: .init(Cardinal(UInt(elements.count))))
        for element in elements {
            buffer.push.back(element)
        }
        self = buffer
    }
}
