// MARK: - Unified Iterator for Linear buffers

extension Buffer.Linear where Element: Copyable {
    /// Iterator that provides both element-at-a-time and span-based iteration
    /// for linear storage.
    @safe
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol, @unchecked Sendable {
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

extension Buffer.Linear: Sequence.`Protocol`, Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let base = unsafe UnsafePointer(storage.pointer(at: .zero))
        return unsafe Iterator(base: base, count: header.count)
    }
}

extension Buffer.Linear: Swift.Sequence where Element: Copyable {
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: header.count) }
}

extension Buffer.Linear.Bounded where Element: Copyable {
    /// Iterator that provides both element-at-a-time and span-based iteration
    /// for linear storage.
    @safe
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        var base: UnsafePointer<Element>

        @usableFromInline
        var remaining: Index<Element>.Count

        @inlinable
        internal init(base: UnsafePointer<Element>, count: Index<Element>.Count) {
            unsafe self.base = base
            self.remaining = count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard remaining > .zero else { return nil }
            let element = unsafe base.pointee
            unsafe base = base + 1
            remaining = remaining.subtract.saturating(.one)
            return element
        }

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

extension Buffer.Linear.Bounded: Sequence.`Protocol`, Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let base = unsafe UnsafePointer(storage.pointer(at: .zero))
        return unsafe Iterator(base: base, count: header.count)
    }
}

extension Buffer.Linear.Bounded: Swift.Sequence where Element: Copyable {
    @inlinable
    public var underestimatedCount: Int { Int(bitPattern: header.count) }
}
