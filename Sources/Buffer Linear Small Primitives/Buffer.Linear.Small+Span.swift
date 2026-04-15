// MARK: - Span / MutableSpan for Linear.Small

extension Buffer.Linear.Small where Element: ~Copyable {
    /// Read-only span of all buffer elements.
    ///
    /// Constructs the span from raw storage pointers to avoid
    /// DiagnoseStaticExclusivity crash when delegating through enum payloads.
    public var span: Span<Element> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            switch _storage {
            case .heap(let heap):
                let span = unsafe Span(
                    _unsafeStart: UnsafePointer(heap.storage.pointer(at: .zero)),
                    count: heap.header.count
                )
                return unsafe _overrideLifetime(span, borrowing: self)
            case .inline(let buf):
                let inlineBounded = Index<Element>.Bounded<inlineCapacity>(.zero)!
                let span = unsafe Span(
                    _unsafeStart: UnsafePointer(buf.storage.pointer(at: inlineBounded)),
                    count: buf.header.count
                )
                return unsafe _overrideLifetime(span, borrowing: self)
            }
        }
    }

    /// Mutable span of all buffer elements.
    ///
    /// `mutating get` extracts pointer and count from the enum, then constructs
    /// the span outside the switch to avoid overlapping access on `self`.
    ///
    /// `_modify` spills inline storage to heap first, then yields through the
    /// heap pointer. Inline storage cannot yield through `_modify` because
    /// enum payloads do not support `_modify` projection (only Optional has
    /// special compiler support via `unchecked_take_enum_data_addr`).
    /// See: Experiments/small-enum-modify-recovery (2026-02-16)
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        @inlinable
        mutating get {
            let start: UnsafeMutablePointer<Element>
            let elementCount: Index<Element>.Count
            switch _storage {
            case .heap(let heap):
                unsafe start = heap.storage.pointer(at: .zero)
                elementCount = heap.header.count
            case .inline(let buf):
                let inlineBounded = Index<Element>.Bounded<inlineCapacity>(.zero)!
                unsafe start = buf.storage.pointer(at: inlineBounded)
                elementCount = buf.header.count
            }
            let span = unsafe MutableSpan(_unsafeStart: start, count: elementCount)
            return unsafe _overrideLifetime(span, mutating: &self)
        }
        @_lifetime(&self)
        @inlinable
        _modify {
            _spillToHeapMoving()
            switch _storage {
            case .heap(let heap):
                var span = unsafe MutableSpan(
                    _unsafeStart: unsafe heap.storage.pointer(at: .zero),
                    count: heap.header.count
                )
                yield &span
            case .inline:
                fatalError("unreachable: _spillToHeapMoving guarantees heap mode")
            }
        }
    }
}

// MARK: - Iterator and Sequence for Linear.Small

extension Buffer.Linear.Small where Element: Copyable {
    /// Iterator that provides both element-at-a-time and span-based iteration
    /// for small linear storage.
    @safe
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol, @unsafe @unchecked Sendable {
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

        // MARK: Sequence.Iterator.Protocol (nextSpan)

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
        switch _storage {
        case .heap(let heap):
            let base = unsafe UnsafePointer(heap.storage.pointer(at: .zero))
            return unsafe Iterator(base: base, count: heap.count)
        case .inline(let buf):
            let inlineBounded = Index<Element>.Bounded<inlineCapacity>(.zero)!
            let base: UnsafePointer<Element> = unsafe buf.storage.pointer(at: inlineBounded)
            return unsafe Iterator(base: base, count: buf.count)
        }
    }
}
