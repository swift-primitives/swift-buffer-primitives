// MARK: - ~Copyable forEach for Linear

extension Buffer.Linear where Element: ~Copyable {
    /// Calls `body` with a borrow of each element in order.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        var slot: Index<Element> = .zero
        let end = header.count.map(Ordinal.init)
        while slot < end {
            try body(unsafe storage.pointer(at: slot).pointee)
            slot += .one
        }
    }
}

// MARK: - ~Copyable forEach for Linear.Bounded

extension Buffer.Linear.Bounded where Element: ~Copyable {
    /// Calls `body` with a borrow of each element in order.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        var slot: Index<Element> = .zero
        let end = header.count.map(Ordinal.init)
        while slot < end {
            try body(unsafe storage.pointer(at: slot).pointee)
            slot += .one
        }
    }
}

// MARK: - ~Copyable forEach for Linear.Inline

extension Buffer.Linear.Inline where Element: ~Copyable {
    /// Calls `body` with a borrow of each element in order.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        var slot: Index<Element> = .zero
        let end = header.count.map(Ordinal.init)
        while slot < end {
            try body(unsafe storage.pointer(at: slot).pointee)
            slot += .one
        }
    }
}

// MARK: - ~Copyable forEach for Linear.Small

extension Buffer.Linear.Small where Element: ~Copyable {
    /// Calls `body` with a borrow of each element in order.
    @inlinable
    public func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        switch _heapBuffer {
        case .some(let heap): try heap.forEach(body)
        case .none: try _inlineBuffer.forEach(body)
        }
    }
}
