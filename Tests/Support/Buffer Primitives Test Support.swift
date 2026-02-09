// MARK: - Ring

extension Buffer.Ring {
    @inlinable
    public init(_ elements: [Element], minimumCapacity: UInt = 0) {
        let cap: Index<Element>.Count = .init(Cardinal(Swift.max(UInt(elements.count), minimumCapacity)))
        var buffer = Self(minimumCapacity: cap)
        for element in elements {
            buffer.pushBack(element)
        }
        self = buffer
    }
}
