// MARK: - Sequence.Borrowing.Protocol for Linear buffers

extension Buffer.Linear.Growable where Element: Copyable {
    /// Borrowing iterator that returns contiguous spans from linear storage.
    ///
    /// Advances the stored base pointer on each call to `nextSpan` so
    /// the returned `Span` depends on `self` directly.
    @safe
    public struct BorrowingIterator: Sequence.Iterator.Borrowing.`Protocol` {
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
        @_lifetime(&self)
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            let take = min(maximumCount.rawValue, remaining)
            guard take > 0 else {
                return unsafe Span(_unsafeStart: base, count: 0)
            }
            let span = unsafe Span(_unsafeStart: base, count: Int(bitPattern: take))
            unsafe base = base + Int(bitPattern: take)
            remaining &-= take
            return span
        }
    }
}

extension Buffer.Linear.Growable: Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> BorrowingIterator {
        let base = unsafe UnsafePointer(storage.pointer(at: .zero))
        return unsafe BorrowingIterator(base: base, count: header.count.rawValue.rawValue)
    }
}

extension Buffer.Linear.Bounded where Element: Copyable {
    /// Borrowing iterator that returns contiguous spans from linear storage.
    @safe
    public struct BorrowingIterator: Sequence.Iterator.Borrowing.`Protocol` {
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
        @_lifetime(&self)
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            let take = min(maximumCount.rawValue, remaining)
            guard take > 0 else {
                return unsafe Span(_unsafeStart: base, count: 0)
            }
            let span = unsafe Span(_unsafeStart: base, count: Int(bitPattern: take))
            unsafe base = base + Int(bitPattern: take)
            remaining &-= take
            return span
        }
    }
}

extension Buffer.Linear.Bounded: Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> BorrowingIterator {
        let base = unsafe UnsafePointer(storage.pointer(at: .zero))
        return unsafe BorrowingIterator(base: base, count: header.count.rawValue.rawValue)
    }
}
