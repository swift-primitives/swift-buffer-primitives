// MARK: - Span / MutableSpan for Linear.Inline

extension Buffer.Linear.Inline where Element: ~Copyable {
    /// Read-only span of all buffer elements.
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let ptr = unsafe UnsafePointer(storage.pointer(at: .zero))
            let count = Int(bitPattern: header.count.rawValue.rawValue)
            let span = unsafe Span(_unsafeStart: ptr, count: count)
            return unsafe _overrideLifetime(span, borrowing: self)
        }
    }

    /// Mutable span of all buffer elements.
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            let ptr: UnsafeMutablePointer<Element> = unsafe storage.pointer(at: .zero)
            let count = Int(bitPattern: header.count.rawValue.rawValue)
            let span = unsafe MutableSpan(_unsafeStart: ptr, count: count)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        @_lifetime(&self)
        @inlinable
        _modify {
            let ptr: UnsafeMutablePointer<Element> = unsafe storage.pointer(at: .zero)
            let count = Int(bitPattern: header.count.rawValue.rawValue)
            var span = unsafe MutableSpan(_unsafeStart: ptr, count: count)
            yield &span
        }
    }
}
