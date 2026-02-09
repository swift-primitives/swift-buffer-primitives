extension Buffer.Linear: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        let cap: Index<Element>.Count = .init(Cardinal(Swift.max(UInt(elements.count), 0)))
        var buffer = Self(minimumCapacity: cap)
        for element in elements {
            buffer.append(element)
        }
        self = buffer
    }
}
