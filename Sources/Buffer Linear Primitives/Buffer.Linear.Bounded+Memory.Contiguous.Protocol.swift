// MARK: - Span / MutableSpan for Linear.Bounded

extension Buffer.Linear.Bounded where Element: ~Copyable {
    /// Read-only span of all buffer elements.
    ///
    /// Pointer from storage, count from buffer header (source of truth).
    /// Buffer header and storage header may diverge between growth events,
    /// so we must NOT delegate to `storage.span`.
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let count = Int(bitPattern: header.count)
            let span = unsafe Span(
                _unsafeStart: storage.pointer(at: .zero),
                count: count
            )
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    /// Mutable span of all buffer elements.
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            let count = Int(bitPattern: header.count)
            let span = unsafe MutableSpan(
                _unsafeStart: unsafe storage.pointer(at: .zero),
                count: count
            )
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        @_lifetime(&self)
        @inlinable
        _modify {
            let count = Int(bitPattern: header.count)
            var span = unsafe MutableSpan(
                _unsafeStart: unsafe storage.pointer(at: .zero),
                count: count
            )
            yield &span
        }
    }
}

// MARK: - Memory.Contiguous.Protocol Conformance for Linear.Bounded

extension Buffer.Linear.Bounded: Memory.Contiguous.`Protocol` where Element: Copyable {
    /// Unsafe read access for C interop with unannotated APIs.
    @inlinable
    public func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let count = Int(bitPattern: header.count)
        return try unsafe body(UnsafeBufferPointer(
            start: count > 0 ? storage.pointer(at: .zero) : nil,
            count: count
        ))
    }
}

extension Buffer.Linear.Bounded where Element: Copyable {
    /// Unsafe mutable access for C interop with unannotated APIs.
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        let count = Int(bitPattern: header.count)
        return try unsafe body(UnsafeMutableBufferPointer(
            start: count > 0 ? storage.pointer(at: .zero) : nil,
            count: count
        ))
    }
}
