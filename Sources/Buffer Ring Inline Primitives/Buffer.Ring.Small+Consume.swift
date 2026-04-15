// MARK: - Sequence.Consume support for Ring.Small

extension Buffer.Ring.Small where Element: ~Copyable {
    /// State for consuming iteration — deinitializes remaining elements on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    ///
    /// Elements are always linearized to heap storage for safe iteration.
    public final class ConsumeState: @unsafe @unchecked Sendable {
        @usableFromInline
        var header: Buffer.Ring.Header

        @usableFromInline
        let storage: Storage<Element>.Heap

        @inlinable
        package init(header: Buffer.Ring.Header, storage: Storage<Element>.Heap) {
            self.header = header
            self.storage = storage
        }

        deinit {
            var h = header
            Buffer.Ring.deinitializeAll(header: &h, storage: storage)
        }
    }
}

extension Buffer.Ring.Small where Element: Copyable {
    /// Consumes the buffer's elements into a consuming view.
    ///
    /// If in heap mode, takes the heap storage directly.
    /// If in inline mode, linearizes ring elements to heap storage first.
    /// The buffer is left empty in inline mode.
    ///
    /// - Returns: A consuming view for element-by-element iteration.
    @inlinable
    public mutating func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        switch _storage {
        case .heap(let heap):
            let header = heap.header
            let storage = heap.storage
            self = Self(_storage: .inline(Buffer<Element>.Ring.Inline<inlineCapacity>()))
            _ = consume heap
            return Sequence.Consume.View(
                state: ConsumeState(header: header, storage: storage),
                next: { state in
                    guard !state.header.isEmpty else { return nil }
                    return Buffer.Ring.popFront(header: &state.header, storage: state.storage)
                }
            )
        case .inline(var buf):
            let currentCount = buf.count
            let heapStorage = Storage<Element>.Heap.create(minimumCapacity: currentCount)

            if currentCount > .zero {
                // Linearize inline ring elements to heap in FIFO order
                Buffer.Ring.linearize(
                    header: buf.header,
                    source: buf.storage,
                    to: heapStorage
                )
            }

            // Reset inline state
            buf.header = Buffer.Ring.Header(
                capacity: Index<Element>.Count(UInt(inlineCapacity))
            )
            buf.storage.initialization = .empty
            self = Self(_storage: .inline(consume buf))

            var newHeader = Buffer.Ring.Header(capacity: heapStorage.slotCapacity)
            newHeader.count = currentCount
            heapStorage.initialization = newHeader.initialization

            return Sequence.Consume.View(
                state: ConsumeState(header: newHeader, storage: heapStorage),
                next: { state in
                    guard !state.header.isEmpty else { return nil }
                    return Buffer.Ring.popFront(header: &state.header, storage: state.storage)
                }
            )
        }
    }
}
