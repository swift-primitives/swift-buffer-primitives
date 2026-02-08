// MARK: - Span / MutableSpan for Linear.Inline

extension Buffer.Linear.Inline where Element: ~Copyable {
    /// Read-only span of all buffer elements.
    ///
    /// Delegates to `Storage.Inline`'s span implementation.
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let span = storage.span
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    /// Mutable span of all buffer elements.
    ///
    /// Delegates to `Storage.Inline`'s mutableSpan implementation.
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            let span = storage.mutableSpan
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        @_lifetime(&self)
        @inlinable
        _modify {
            var span = storage.mutableSpan
            defer { span = unsafe _overrideLifetime(span, mutating: &self) }
            yield &span
        }
    }
}
