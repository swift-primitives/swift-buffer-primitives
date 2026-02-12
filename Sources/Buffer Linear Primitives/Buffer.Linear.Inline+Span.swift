// MARK: - Span / MutableSpan for Linear.Inline

extension Buffer.Linear.Inline where Element: ~Copyable {
    /// Read-only span of all buffer elements.
    ///
    /// Pointer from storage, count from buffer header (source of truth).
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
                _unsafeStart: unsafe UnsafeMutablePointer(mutating: storage.pointer(at: .zero)),
                count: header.count
            )
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        @_lifetime(&self)
        @inlinable
        _modify {
            var span = unsafe MutableSpan(
                _unsafeStart: unsafe UnsafeMutablePointer(mutating: storage.pointer(at: .zero)),
                count: header.count
            )
            yield &span
        }
    }
}
