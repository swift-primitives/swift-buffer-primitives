// MARK: - Unified Iterator for Linear buffers (Sequence.Protocol + Sequence.Borrowing.Protocol)

extension Buffer.Linear where Element: Copyable {
    /// Iterator that provides both element-at-a-time and span-based iteration
    /// for linear storage.
    @safe
    public struct Iterator: Sequence.Iterator.Borrowing.`Protocol`, IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        var base: UnsafePointer<Element>

        @usableFromInline
        var remaining: UInt

        @inlinable
        internal init(base: UnsafePointer<Element>, count: UInt) {
            unsafe self.base = base
            self.remaining = count
        }

        // MARK: IteratorProtocol

        @inlinable
        public mutating func next() -> Element? {
            guard remaining > 0 else { return nil }
            let element = unsafe base.pointee
            unsafe base = base + 1
            remaining &-= 1
            return element
        }

        // MARK: Sequence.Iterator.Borrowing.Protocol

        @inlinable
        @_lifetime(&self)
        public mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element> {
            let take = min(maximumCount.rawValue, remaining)
            guard take > 0 else {
                return unsafe Swift.Span(_unsafeStart: base, count: 0)
            }
            let span = unsafe Swift.Span(_unsafeStart: base, count: Int(bitPattern: take))
            unsafe base = base + Int(bitPattern: take)
            remaining &-= take
            return span
        }
    }
}

extension Buffer.Linear: Sequence.`Protocol`, Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let base = unsafe UnsafePointer(storage.pointer(at: .zero))
        return unsafe Iterator(base: base, count: header.count.rawValue.rawValue)
    }
}

extension Buffer.Linear.Bounded where Element: Copyable {
    /// Iterator that provides both element-at-a-time and span-based iteration
    /// for linear storage.
    @safe
    public struct Iterator: Sequence.Iterator.Borrowing.`Protocol`, IteratorProtocol, @unchecked Sendable {
        @usableFromInline
        var base: UnsafePointer<Element>

        @usableFromInline
        var remaining: UInt

        @inlinable
        internal init(base: UnsafePointer<Element>, count: UInt) {
            unsafe self.base = base
            self.remaining = count
        }

        @inlinable
        public mutating func next() -> Element? {
            guard remaining > 0 else { return nil }
            let element = unsafe base.pointee
            unsafe base = base + 1
            remaining &-= 1
            return element
        }

        @inlinable
        @_lifetime(&self)
        public mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element> {
            let take = min(maximumCount.rawValue, remaining)
            guard take > 0 else {
                return unsafe Swift.Span(_unsafeStart: base, count: 0)
            }
            let span = unsafe Swift.Span(_unsafeStart: base, count: Int(bitPattern: take))
            unsafe base = base + Int(bitPattern: take)
            remaining &-= take
            return span
        }
    }
}

extension Buffer.Linear.Bounded: Sequence.`Protocol`, Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let base = unsafe UnsafePointer(storage.pointer(at: .zero))
        return unsafe Iterator(base: base, count: header.count.rawValue.rawValue)
    }
}
