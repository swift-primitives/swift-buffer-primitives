// MARK: - Sequence.Borrowing.Protocol for Ring buffers

extension Buffer.Ring.Growable where Element: Copyable {
    /// Borrowing iterator that returns contiguous spans from ring storage.
    ///
    /// When the ring wraps, returns two separate spans: one for the
    /// first contiguous region (head to capacity) and one for the
    /// second (zero to tail).
    ///
    /// Advances the stored base pointer on each `nextSpan` call so
    /// the returned `Span` depends on `self` directly.
    @safe
    public struct BorrowingIterator: Sequence.Iterator.Borrowing.`Protocol` {
        @usableFromInline
        var base: UnsafePointer<Element>

        /// Remaining elements in the current region.
        @usableFromInline
        var remaining: UInt

        /// Start of the second region (nil if no second region or already consumed).
        @usableFromInline
        var secondBase: UnsafePointer<Element>?

        /// Element count in the second region.
        @usableFromInline
        var secondCount: UInt

        @inlinable
        internal init(
            storageBase: UnsafePointer<Element>,
            header: Buffer.Ring.Header
        ) {
            switch header.initialization {
            case .empty:
                unsafe self.base = storageBase
                self.remaining = 0
                unsafe self.secondBase = nil
                self.secondCount = 0

            case .one(let range):
                let startOrd = range.lowerBound.rawValue.rawValue
                unsafe self.base = storageBase + Int(bitPattern: startOrd)
                self.remaining = range.count.rawValue.rawValue
                unsafe self.secondBase = nil
                self.secondCount = 0

            case .two(let first, let second):
                let firstStart = first.lowerBound.rawValue.rawValue
                unsafe self.base = storageBase + Int(bitPattern: firstStart)
                self.remaining = first.count.rawValue.rawValue
                let secondStart = second.lowerBound.rawValue.rawValue
                unsafe self.secondBase = storageBase + Int(bitPattern: secondStart)
                self.secondCount = second.count.rawValue.rawValue
            }
        }

        @inlinable
        @_lifetime(&self)
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            // Try current region first
            if remaining > 0 {
                let take = min(maximumCount.rawValue, remaining)
                let span = unsafe Span(_unsafeStart: base, count: Int(bitPattern: take))
                unsafe base = base + Int(bitPattern: take)
                remaining &-= take
                return span
            }

            // Transition to second region if available
            if let second = unsafe secondBase, secondCount > 0 {
                unsafe base = second
                remaining = secondCount
                unsafe secondBase = nil
                secondCount = 0

                let take = min(maximumCount.rawValue, remaining)
                let span = unsafe Span(_unsafeStart: base, count: Int(bitPattern: take))
                unsafe base = base + Int(bitPattern: take)
                remaining &-= take
                return span
            }

            // Exhausted
            return unsafe Span(_unsafeStart: base, count: 0)
        }
    }
}

extension Buffer.Ring.Growable: Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> BorrowingIterator {
        let base = unsafe UnsafePointer(storage.pointer(at: .zero))
        return unsafe BorrowingIterator(storageBase: base, header: header)
    }
}

extension Buffer.Ring.Bounded where Element: Copyable {
    /// Borrowing iterator that returns contiguous spans from ring storage.
    @safe
    public struct BorrowingIterator: Sequence.Iterator.Borrowing.`Protocol` {
        @usableFromInline
        var base: UnsafePointer<Element>

        @usableFromInline
        var remaining: UInt

        @usableFromInline
        var secondBase: UnsafePointer<Element>?

        @usableFromInline
        var secondCount: UInt

        @inlinable
        internal init(
            storageBase: UnsafePointer<Element>,
            header: Buffer.Ring.Header
        ) {
            switch header.initialization {
            case .empty:
                unsafe self.base = storageBase
                self.remaining = 0
                unsafe self.secondBase = nil
                self.secondCount = 0

            case .one(let range):
                let startOrd = range.lowerBound.rawValue.rawValue
                unsafe self.base = storageBase + Int(bitPattern: startOrd)
                self.remaining = range.count.rawValue.rawValue
                unsafe self.secondBase = nil
                self.secondCount = 0

            case .two(let first, let second):
                let firstStart = first.lowerBound.rawValue.rawValue
                unsafe self.base = storageBase + Int(bitPattern: firstStart)
                self.remaining = first.count.rawValue.rawValue
                let secondStart = second.lowerBound.rawValue.rawValue
                unsafe self.secondBase = storageBase + Int(bitPattern: secondStart)
                self.secondCount = second.count.rawValue.rawValue
            }
        }

        @inlinable
        @_lifetime(&self)
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            if remaining > 0 {
                let take = min(maximumCount.rawValue, remaining)
                let span = unsafe Span(_unsafeStart: base, count: Int(bitPattern: take))
                unsafe base = base + Int(bitPattern: take)
                remaining &-= take
                return span
            }

            if let second = unsafe secondBase, secondCount > 0 {
                unsafe base = second
                remaining = secondCount
                unsafe secondBase = nil
                secondCount = 0

                let take = min(maximumCount.rawValue, remaining)
                let span = unsafe Span(_unsafeStart: base, count: Int(bitPattern: take))
                unsafe base = base + Int(bitPattern: take)
                remaining &-= take
                return span
            }

            return unsafe Span(_unsafeStart: base, count: 0)
        }
    }
}

extension Buffer.Ring.Bounded: Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> BorrowingIterator {
        let base = unsafe UnsafePointer(storage.pointer(at: .zero))
        return unsafe BorrowingIterator(storageBase: base, header: header)
    }
}
