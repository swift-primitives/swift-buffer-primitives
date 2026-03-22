// MARK: - Ring

extension Buffer.Ring {
    @inlinable
    public init(_ elements: [Element], minimumCapacity: UInt = 0) {
        let cap: Index<Element>.Count = .init(Cardinal(Swift.max(UInt(elements.count), minimumCapacity)))
        var buffer = Self(minimumCapacity: cap)
        for element in elements {
            buffer.push.back(element)
        }
        self = buffer
    }
}

extension Buffer.Ring.Small {
    @inlinable
    public init(_ elements: [Element]) {
        var buffer = Self()
        for element in elements {
            buffer.push.back(element)
        }
        self = buffer
    }
}

// MARK: - Linear

extension Buffer.Linear {
    @inlinable
    public init(_ elements: [Element], minimumCapacity: UInt = 0) {
        let cap: Index<Element>.Count = .init(Cardinal(Swift.max(UInt(elements.count), minimumCapacity)))
        var buffer = Self(minimumCapacity: cap)
        for element in elements {
            buffer.append(element)
        }
        self = buffer
    }
}

extension Buffer.Linear.Small {
    @inlinable
    public init(_ elements: [Element]) {
        var buffer = Self()
        for element in elements {
            buffer.append(element)
        }
        self = buffer
    }
}

// MARK: - Linked

extension Buffer.Linked {
    // Swift 6.2 CopyPropagation crash: double-consume of Property.View.Typed.Valued
    public init(_ elements: [Element], minimumCapacity: UInt = 0) {
        let cap = Index<Node>.Count(Cardinal(Swift.max(UInt(elements.count), minimumCapacity)))
        var buffer = Self(minimumCapacity: cap)
        for element in elements {
            buffer.insert.back(element)
        }
        self = buffer
    }
}

extension Buffer.Linked.Small {
    // Swift 6.2 CopyPropagation crash: double-consume of Property.View.Typed.Valued
    public init(_ elements: [Element]) {
        var buffer = Self()
        for element in elements {
            buffer.insert.back(element)
        }
        self = buffer
    }
}
