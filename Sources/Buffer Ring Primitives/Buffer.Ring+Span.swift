// MARK: - Unified Iterator for Ring buffers (Sequence.Protocol + Sequence.Borrowing.Protocol)

extension Buffer.Ring.Growable where Element: Copyable {
    /// Iterator that provides both element-at-a-time and span-based iteration
    /// for ring storage.
    ///
    /// When the ring wraps, handles two contiguous regions: head-to-capacity
    /// and zero-to-tail.
    @safe
    public struct Iterator: Sequence.Iterator.Borrowing.`Protocol`, IteratorProtocol, @unchecked Sendable {
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

        // MARK: IteratorProtocol

        @inlinable
        public mutating func next() -> Element? {
            if remaining > 0 {
                let element = unsafe base.pointee
                unsafe base = base + 1
                remaining &-= 1
                return element
            }

            if let second = unsafe secondBase, secondCount > 0 {
                unsafe base = second
                remaining = secondCount
                unsafe secondBase = nil
                secondCount = 0

                let element = unsafe base.pointee
                unsafe base = base + 1
                remaining &-= 1
                return element
            }

            return nil
        }

        // MARK: Sequence.Iterator.Borrowing.Protocol

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

extension Buffer.Ring.Growable: Sequence.`Protocol`, Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let base = unsafe UnsafePointer(storage.pointer(at: .zero))
        return unsafe Iterator(storageBase: base, header: header)
    }
}

extension Buffer.Ring.Bounded where Element: Copyable {
    /// Iterator that provides both element-at-a-time and span-based iteration
    /// for ring storage.
    @safe
    public struct Iterator: Sequence.Iterator.Borrowing.`Protocol`, IteratorProtocol, @unchecked Sendable {
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
        public mutating func next() -> Element? {
            if remaining > 0 {
                let element = unsafe base.pointee
                unsafe base = base + 1
                remaining &-= 1
                return element
            }

            if let second = unsafe secondBase, secondCount > 0 {
                unsafe base = second
                remaining = secondCount
                unsafe secondBase = nil
                secondCount = 0

                let element = unsafe base.pointee
                unsafe base = base + 1
                remaining &-= 1
                return element
            }

            return nil
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

extension Buffer.Ring.Bounded: Sequence.`Protocol`, Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        let base = unsafe UnsafePointer(storage.pointer(at: .zero))
        return unsafe Iterator(storageBase: base, header: header)
    }
}
