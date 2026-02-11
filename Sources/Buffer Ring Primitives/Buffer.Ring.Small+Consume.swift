// MARK: - Sequence.Consume support for Ring.Small

extension Buffer.Ring.Small where Element: ~Copyable {
    /// State for consuming iteration — deinitializes remaining elements on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    ///
    /// Elements are always linearized to heap storage for safe iteration.
    public final class ConsumeState: @unchecked Sendable {
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
        if _heapBuffer != nil {
            let header = _heapBuffer!.header
            let storage = _heapBuffer!.storage
            _heapBuffer = nil
            return Sequence.Consume.View(
                state: ConsumeState(header: header, storage: storage),
                next: { state in
                    guard !state.header.isEmpty else { return nil }
                    return Buffer.Ring.popFront(header: &state.header, storage: state.storage)
                }
            )
        } else {
            let currentCount = _inlineBuffer.count
            let heapStorage = Storage<Element>.Heap.create(minimumCapacity: currentCount)

            if currentCount > .zero {
                // Linearize inline ring elements to heap in FIFO order
                Buffer.Ring.linearize(
                    header: _inlineBuffer.header,
                    source: _inlineBuffer.storage,
                    to: heapStorage
                )
            }

            // Reset inline state
            _inlineBuffer.header = Buffer.Ring.Header(
                capacity: Index<Element>.Count(Cardinal(UInt(inlineCapacity)))
            )
            _inlineBuffer.storage.initialization = .empty

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
