// MARK: - Span / MutableSpan for Linear.Small

extension Buffer.Linear.Small where Element: ~Copyable {
    /// Read-only span of all buffer elements.
    ///
    /// Uses `switch` for borrowing access to `_heapBuffer` (SE-0432).
    /// Dispatches to the active buffer's span.
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            switch _heapBuffer {
            case .some(let heap):
                let span = heap.span
                return unsafe _overrideLifetime(span, borrowing: self)
            case .none:
                let span = _inlineBuffer.span
                return unsafe _overrideLifetime(span, borrowing: self)
            }
        }
    }

    /// Mutable span of all buffer elements.
    ///
    /// Constructs the span from raw storage pointers to avoid overlapping
    /// access violations (accessing `heap.mutableSpan` and `&self`
    /// simultaneously would overlap on `self`).
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            if _heapBuffer != nil {
                let span = unsafe MutableSpan(
                    _unsafeStart: unsafe heap.storage.pointer(at: .zero),
                    count: heap.header.count
                )
                return unsafe _overrideLifetime(span, mutating: &self)
            } else {
                let span = unsafe MutableSpan(
                    _unsafeStart: unsafe UnsafeMutablePointer(mutating: _inlineBuffer.storage.pointer(at: .zero)),
                    count: _inlineBuffer.header.count
                )
                return unsafe _overrideLifetime(span, mutating: &self)
            }
        }
        @_lifetime(&self)
        @inlinable
        _modify {
            if _heapBuffer != nil {
                var span = unsafe MutableSpan(
                    _unsafeStart: unsafe heap.storage.pointer(at: .zero),
                    count: heap.header.count
                )
                yield &span
            } else {
                var span = unsafe MutableSpan(
                    _unsafeStart: unsafe UnsafeMutablePointer(mutating: _inlineBuffer.storage.pointer(at: .zero)),
                    count: _inlineBuffer.header.count
                )
                yield &span
            }
        }
    }
}

// MARK: - Iterator and Sequence for Linear.Small

extension Buffer.Linear.Small where Element: Copyable {
    /// Iterator that provides both element-at-a-time and span-based iteration
    /// for small linear storage.
    @safe
    public struct Iterator: Sequence.Iterator.Borrowing.`Protocol`, IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        var base: UnsafePointer<Element>

        @usableFromInline
        var remaining: Index<Element>.Count

        @inlinable
        internal init(base: UnsafePointer<Element>, count: Index<Element>.Count) {
            unsafe self.base = base
            self.remaining = count
        }

        // MARK: IteratorProtocol

        @inlinable
        public mutating func next() -> Element? {
            guard remaining > .zero else { return nil }
            let element = unsafe base.pointee
            unsafe base = base + 1
            remaining = remaining.subtract.saturating(.one)
            return element
        }

        // MARK: Sequence.Iterator.Borrowing.Protocol

        @inlinable
        @_lifetime(&self)
        public mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element> {
            let take = Index<Element>.Count.min(.init(maximumCount), remaining)
            guard take > .zero else {
                return unsafe Swift.Span(_unsafeStart: base, count: 0)
            }
            let span = unsafe Swift.Span(_unsafeStart: base, count: take)
            unsafe base = base + Int(bitPattern: take)
            remaining = remaining.subtract.saturating(take)
            return span
        }
    }
}

extension Buffer.Linear.Small: Sequence.`Protocol`, Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        switch _heapBuffer {
        case .some(let heap):
            let base = unsafe UnsafePointer(heap.storage.pointer(at: .zero))
            return unsafe Iterator(base: base, count: heap.count)
        case .none:
            let base = unsafe _inlineBuffer.storage.pointer(at: .zero)
            return unsafe Iterator(base: base, count: _inlineBuffer.count)
        }
    }
}
