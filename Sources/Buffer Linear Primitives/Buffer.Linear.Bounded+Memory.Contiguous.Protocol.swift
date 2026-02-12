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
            let span = unsafe Span(
                _unsafeStart: storage.pointer(at: .zero),
                count: header.count
            )
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    /// Mutable span of all buffer elements.
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            let span = unsafe MutableSpan(
                _unsafeStart: unsafe storage.pointer(at: .zero),
                count: header.count
            )
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        @_lifetime(&self)
        @inlinable
        _modify {
            var span = unsafe MutableSpan(
                _unsafeStart: unsafe storage.pointer(at: .zero),
                count: header.count
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
        return try unsafe body(UnsafeBufferPointer(
            start: !header.isEmpty ? storage.pointer(at: .zero) : nil,
            count: header.count
        ))
    }
}

extension Buffer.Linear.Bounded where Element: Copyable {
    /// Unsafe mutable access for C interop with unannotated APIs.
    @inlinable
    public mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        return try unsafe body(UnsafeMutableBufferPointer(
            start: !header.isEmpty ? storage.pointer(at: .zero) : nil,
            count: header.count
        ))
    }
}
