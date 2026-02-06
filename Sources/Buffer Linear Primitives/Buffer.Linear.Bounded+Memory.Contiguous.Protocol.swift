// MARK: - Memory.Contiguous.Protocol Conformance for Linear.Bounded

extension Buffer.Linear.Bounded: Memory.Contiguous.`Protocol` {
    /// Read-only span of all buffer elements.
    ///
    /// Delegates to `Storage.Heap`'s existing span implementation.
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            storage.span
        }
    }

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

// MARK: - Mutable Span (~Copyable, no CoW)

extension Buffer.Linear.Bounded where Element: ~Copyable {
    /// Mutable span of all buffer elements.
    ///
    /// For ~Copyable elements, no copy-on-write is needed.
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            let ptr = unsafe storage.pointer(at: .zero)
            let count = Int(bitPattern: header.count.rawValue.rawValue)
            let span = unsafe MutableSpan(_unsafeStart: ptr, count: count)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        @_lifetime(&self)
        @inlinable
        _modify {
            let ptr = unsafe storage.pointer(at: .zero)
            let count = Int(bitPattern: header.count.rawValue.rawValue)
            var span = unsafe MutableSpan(_unsafeStart: ptr, count: count)
            yield &span
        }
    }
}
