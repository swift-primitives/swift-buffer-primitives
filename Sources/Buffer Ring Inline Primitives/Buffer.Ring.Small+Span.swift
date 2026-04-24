// MARK: - Iterator and Sequence for Ring.Small


extension Buffer.Ring.Small where Element: Copyable {
    /// Iterator that provides both element-at-a-time and span-based iteration
    /// for small ring storage.
    ///
    /// When the ring wraps, handles two contiguous regions: head-to-capacity
    /// and zero-to-tail. Works in both inline and heap modes.
    @safe
    public struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol, @unsafe @unchecked Sendable {
        @usableFromInline
        var base: UnsafePointer<Element>

        /// Remaining elements in the current region.
        @usableFromInline
        var remaining: Index<Element>.Count

        /// Start of the second region (nil if no second region or already consumed).
        @usableFromInline
        var secondBase: UnsafePointer<Element>?

        /// Element count in the second region.
        @usableFromInline
        var secondCount: Index<Element>.Count

        @inlinable
        internal init(
            storageBase: UnsafePointer<Element>,
            header: Buffer.Ring.Header
        ) {
            switch header.initialization {
            case .empty:
                unsafe self.base = storageBase
                self.remaining = .zero
                unsafe self.secondBase = nil
                self.secondCount = .zero

            case .one(let range):
                unsafe self.base = storageBase + Int(bitPattern: range.lowerBound)
                self.remaining = range.count
                unsafe self.secondBase = nil
                self.secondCount = .zero

            case .two(let first, let second):
                unsafe self.base = storageBase + Int(bitPattern: first.lowerBound)
                self.remaining = first.count
                unsafe self.secondBase = storageBase + Int(bitPattern: second.lowerBound)
                self.secondCount = second.count
            }
        }

        // MARK: IteratorProtocol

        @inlinable
        public mutating func next() -> Element? {
            if remaining > .zero {
                let element = unsafe base.pointee
                unsafe base = base + 1
                remaining = remaining.subtract.saturating(.one)
                return element
            }

            if let second = unsafe secondBase, secondCount > .zero {
                unsafe base = second
                remaining = secondCount
                unsafe secondBase = nil
                secondCount = .zero

                let element = unsafe base.pointee
                unsafe base = base + 1
                remaining = remaining.subtract.saturating(.one)
                return element
            }

            return nil
        }

        // MARK: Sequence.Iterator.Protocol (nextSpan)

        @inlinable
        @_lifetime(&self)
        public mutating func nextSpan(maximumCount: Cardinal) -> Span<Element> {
            if remaining > .zero {
                let take = Index<Element>.Count.min(.init(maximumCount), remaining)
                let span = unsafe Swift.Span(_unsafeStart: base, count: take)
                unsafe base = base + Int(bitPattern: take)
                remaining = remaining.subtract.saturating(take)
                return span
            }

            if let second = unsafe secondBase, secondCount > .zero {
                unsafe base = second
                remaining = secondCount
                unsafe secondBase = nil
                secondCount = .zero

                let take = Index<Element>.Count.min(.init(maximumCount), remaining)
                let span = unsafe Swift.Span(_unsafeStart: base, count: take)
                unsafe base = base + Int(bitPattern: take)
                remaining = remaining.subtract.saturating(take)
                return span
            }

            return unsafe Swift.Span(_unsafeStart: base, count: 0)
        }
    }
}

extension Buffer.Ring.Small: Sequence.`Protocol`, Sequence.Borrowing.`Protocol` where Element: Copyable {
    @inlinable
    public borrowing func makeIterator() -> Iterator {
        switch _storage {
        case .heap(let heap):
            let base = unsafe UnsafePointer(heap.storage.pointer(at: .zero))
            return unsafe Iterator(storageBase: base, header: heap.header)
        case .inline(let buf):
            let bounded = Index<Element>.Bounded<inlineCapacity>(.zero)!
            let base: UnsafePointer<Element> = unsafe buf.storage.pointer(at: bounded)
            return unsafe Iterator(storageBase: base, header: buf.header)
        }
    }
}
