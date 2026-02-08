// MARK: - Span / MutableSpan for Linear

extension Buffer.Linear where Element: ~Copyable {
    /// Read-only span of all buffer elements.
    ///
    /// Delegates to `Storage.Heap`'s span implementation.
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let span = storage.span
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    /// Mutable span of all buffer elements.
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            let count = Int(bitPattern: header.count.rawValue.rawValue)
            let span = unsafe MutableSpan(_unsafeStart: unsafe storage.pointer(at: .zero), count: count)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        @_lifetime(&self)
        @inlinable
        _modify {
            let count = Int(bitPattern: header.count.rawValue.rawValue)
            var span = unsafe MutableSpan(_unsafeStart: unsafe storage.pointer(at: .zero), count: count)
            yield &span
        }
    }
}

// MARK: - Memory.Contiguous.Protocol Conformance for Linear

extension Buffer.Linear: Memory.Contiguous.`Protocol` where Element: Copyable {
    /// Unsafe read access for C interop with unannotated APIs.
    ///
    /// Delegates to `Storage.Heap`'s existing implementation.
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        unsafe try storage.withUnsafeBufferPointer(body)
    }
}

extension Buffer.Linear where Element: Copyable {
    /// Unsafe mutable access for C interop with unannotated APIs.
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let count = Int(bitPattern: header.count.rawValue.rawValue)
        return try unsafe body(UnsafeMutableBufferPointer(
            start: count > 0 ? storage.pointer(at: .zero) : nil,
            count: count
        ))
    }
}
