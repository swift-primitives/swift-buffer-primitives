// MARK: - Ring Factory Methods

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
    /// Creates a growable ring buffer pre-filled with the given elements.
    @inlinable
    public static func with(_ elements: [Int], minimumCapacity: UInt = 0) -> Self {
        let cap: Index<Element>.Count = .init(Cardinal(Swift.max(UInt(elements.count), minimumCapacity)))
        var buffer = Self(minimumCapacity: cap)
        for element in elements {
            buffer.pushBack(element)
        }
        return buffer
    }
}

extension Buffer.Ring.Bounded where Element == Int {
    /// Creates a bounded ring buffer pre-filled with the given elements.
    @inlinable
    public static func with(_ elements: [Int], capacity: UInt) -> Self {
        var buffer = Self(minimumCapacity: .init(Cardinal(capacity)))
        for element in elements {
            _ = buffer.pushBack(element)
        }
        return buffer
    }
}

// MARK: - Linear Factory Methods

extension Buffer.Linear where Element == Int {
    /// Creates a growable linear buffer pre-filled with the given elements.
    @inlinable
    public static func with(_ elements: [Int], minimumCapacity: UInt = 0) -> Self {
        let cap: Index<Element>.Count = .init(Cardinal(Swift.max(UInt(elements.count), minimumCapacity)))
        var buffer = Self(minimumCapacity: cap)
        for element in elements {
            buffer.append(element)
        }
        return buffer
    }
}

extension Buffer.Linear.Bounded where Element == Int {
    /// Creates a bounded linear buffer pre-filled with the given elements.
    @inlinable
    public static func with(_ elements: [Int], capacity: UInt) -> Self {
        var buffer = Self(minimumCapacity: .init(Cardinal(capacity)))
        for element in elements {
            _ = buffer.append(element)
        }
        return buffer
    }
}

// MARK: - Slab Factory Methods

extension Buffer.Slab.Bounded where Element == Int {
    /// Creates a bounded slab buffer pre-filled at consecutive slots.
    @inlinable
    public static func with(_ elements: [Int], capacity: UInt) -> Self {
        var buffer = Self(minimumCapacity: .init(Cardinal(capacity)))
        for (i, element) in elements.enumerated() {
            buffer.insert(element, at: Bit.Index(Ordinal(UInt(i))))
        }
        return buffer
    }
}

// MARK: - Inline Ring Factory Methods

extension Buffer.Ring.Inline where Element == Int {
    /// Creates a bounded inline ring buffer pre-filled with the given elements.
    @inlinable
    public static func with(_ elements: [Int]) -> Self {
        var buffer = Self()
        for element in elements {
            _ = buffer.pushBack(element)
        }
        return buffer
    }
}

// MARK: - Inline Linear Factory Methods

extension Buffer.Linear.Inline where Element == Int {
    /// Creates a bounded inline linear buffer pre-filled with the given elements.
    @inlinable
    public static func with(_ elements: [Int]) -> Self {
        var buffer = Self()
        for element in elements {
            _ = buffer.append(element)
        }
        return buffer
    }
}

// MARK: - Inline Slab Factory Methods

extension Buffer.Slab.Inline where Element == Int {
    /// Creates a bounded inline slab buffer pre-filled at consecutive slots.
    @inlinable
    public static func with(_ elements: [Int]) -> Self {
        var buffer = Self()
        for (i, element) in elements.enumerated() {
            buffer.insert(element, at: Bit.Index(Ordinal(UInt(i))))
        }
        return buffer
    }
}
