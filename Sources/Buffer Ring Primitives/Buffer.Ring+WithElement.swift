// MARK: - Borrowing Element Access for Ring (~Copyable)

extension Buffer.Ring where Element: ~Copyable {

    /// Calls `body` with a borrow of the front element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public func withFront<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R {
        let ptr = unsafe storage.pointer(at: header.head)
        return body(unsafe ptr.pointee)
    }

    /// Calls `body` with a borrow of the back element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public func withBack<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R {
        let lastIndex = header.count.subtract.saturating(.one).map(Ordinal.init)
        let lastOffset = Index<Element>.Offset(fromZero: lastIndex)
        let lastSlot = Index.Modular.advanced(header.head, by: lastOffset, capacity: header.capacity)
        return body(unsafe storage.pointer(at: lastSlot).pointee)
    }
}

// MARK: - Borrowing Element Access for Ring.Bounded (~Copyable)

extension Buffer.Ring.Bounded where Element: ~Copyable {

    /// Calls `body` with a borrow of the front element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public func withFront<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R {
        let ptr = unsafe storage.pointer(at: header.head)
        return body(unsafe ptr.pointee)
    }

    /// Calls `body` with a borrow of the back element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public func withBack<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R {
        let lastIndex = header.count.subtract.saturating(.one).map(Ordinal.init)
        let lastOffset = Index<Element>.Offset(fromZero: lastIndex)
        let lastSlot = Index.Modular.advanced(header.head, by: lastOffset, capacity: header.capacity)
        return body(unsafe storage.pointer(at: lastSlot).pointee)
    }
}

// MARK: - Borrowing Element Access for Ring.Inline (~Copyable)

extension Buffer.Ring.Inline where Element: ~Copyable {

    /// Calls `body` with a borrow of the front element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public func withFront<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R {
        let ptr = unsafe storage.pointer(at: header.head)
        return body(unsafe ptr.pointee)
    }

    /// Calls `body` with a borrow of the back element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public func withBack<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R {
        let lastIndex = header.count.subtract.saturating(.one).map(Ordinal.init)
        let lastOffset = Index<Element>.Offset(fromZero: lastIndex)
        let lastSlot = Index.Modular.advanced(header.head, by: lastOffset, capacity: header.capacity)
        return body(unsafe storage.pointer(at: lastSlot).pointee)
    }
}

// MARK: - Borrowing Element Access for Ring.Small (~Copyable)

extension Buffer.Ring.Small where Element: ~Copyable {

    /// Calls `body` with a borrow of the front element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public func withFront<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R {
        switch _heapBuffer {
        case .some(let heap): return heap.withFront(body)
        case .none: return _inlineBuffer.withFront(body)
        }
    }

    /// Calls `body` with a borrow of the back element.
    ///
    /// - Precondition: The buffer is not empty.
    @inlinable
    public func withBack<R: ~Copyable>(_ body: (borrowing Element) -> R) -> R {
        switch _heapBuffer {
        case .some(let heap): return heap.withBack(body)
        case .none: return _inlineBuffer.withBack(body)
        }
    }
}
