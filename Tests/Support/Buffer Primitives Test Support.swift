// MARK: - Ring

extension Buffer.Ring: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        let cap: Index<Element>.Count = .init(Cardinal(Swift.max(UInt(elements.count), 0)))
        var buffer = Self(minimumCapacity: cap)
        for element in elements {
            buffer.pushBack(element)
        }
        self = buffer
    }
}

extension Buffer.Ring where Element == Int {
    @inlinable
    public init(_ elements: [Int], minimumCapacity: UInt = 0) {
        let cap: Index<Element>.Count = .init(Cardinal(Swift.max(UInt(elements.count), minimumCapacity)))
        var buffer = Self(minimumCapacity: cap)
        for element in elements {
            buffer.pushBack(element)
        }
        self = buffer
    }
}

extension Buffer.Ring.Bounded where Element == Int {
    @inlinable
    public init(_ elements: [Int], capacity: UInt) {
        var buffer = Self(minimumCapacity: .init(Cardinal(capacity)))
        for element in elements {
            _ = buffer.pushBack(element)
        }
        self = buffer
    }
}

// MARK: - Linear

extension Buffer.Linear: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        let cap: Index<Element>.Count = .init(Cardinal(Swift.max(UInt(elements.count), 0)))
        var buffer = Self(minimumCapacity: cap)
        for element in elements {
            buffer.append(element)
        }
        self = buffer
    }
}

extension Buffer.Linear.Bounded {
    @inlinable
    public init(_ elements: [Element], capacity: UInt) {
        var buffer = Self(minimumCapacity: .init(Cardinal(capacity)))
        for element in elements {
            _ = buffer.append(element)
        }
        self = buffer
    }
}

// MARK: - Slab

extension Buffer.Slab.Bounded {
    @inlinable
    public init(_ elements: [Element], capacity: UInt) {
        var buffer = Self(minimumCapacity: .init(Cardinal(capacity)))
        for (i, element) in elements.enumerated() {
            buffer.insert(element, at: Bit.Index(Ordinal(UInt(i))))
        }
        self = buffer
    }
}

extension Buffer.Slab.Inline {
    @inlinable
    public init(_ elements: [Element]) {
        var buffer = Self()
        for (i, element) in elements.enumerated() {
            buffer.insert(element, at: Bit.Index(Ordinal(UInt(i))))
        }
        self = buffer
    }
}

// MARK: - Inline Ring

extension Buffer.Ring.Inline {
    @inlinable
    public init(_ elements: [Element]) {
        var buffer = Self()
        for element in elements {
            _ = buffer.pushBack(element)
        }
        self = buffer
    }
}

// MARK: - Inline Linear

extension Buffer.Linear.Inline {
    @inlinable
    public init(_ elements: [Element]) {
        var buffer = Self()
        for element in elements {
            _ = buffer.append(element)
        }
        self = buffer
    }
}
