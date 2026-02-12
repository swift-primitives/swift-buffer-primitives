// MARK: - Span / MutableSpan for Linear.Inline

extension Buffer.Linear.Inline where Element: ~Copyable {
    /// Read-only span of all buffer elements.
    ///
    /// Pointer from storage, count from buffer header (source of truth).
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let bounded = Index<Element>.Bounded<capacity>(.zero)!
            let start: UnsafePointer<Element> = unsafe storage.pointer(at: bounded)
            let span = unsafe Span(
                _unsafeStart: start,
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
            let bounded = Index<Element>.Bounded<capacity>(.zero)!
            let span = unsafe MutableSpan(
                _unsafeStart: unsafe storage.pointer(at: bounded),
                count: header.count
            )
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        @_lifetime(&self)
        @inlinable
        _modify {
            let bounded = Index<Element>.Bounded<capacity>(.zero)!
            var span = unsafe MutableSpan(
                _unsafeStart: unsafe storage.pointer(at: bounded),
                count: header.count
            )
            yield &span
        }
    }
}
