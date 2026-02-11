extension Buffer.Ring: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        var buffer = Self(minimumCapacity: .init(Cardinal(UInt(elements.count))))
        for element in elements {
            buffer.pushBack(element)
        }
        self = buffer
    }
}
