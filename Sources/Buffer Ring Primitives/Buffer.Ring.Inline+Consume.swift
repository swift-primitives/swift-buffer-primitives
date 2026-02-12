// MARK: - Sequence.Consume support for Ring.Inline

extension Buffer.Ring.Inline where Element: ~Copyable {
    /// State for consuming iteration — deinitializes remaining elements on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    ///
    /// Elements are moved from inline storage to heap storage during `consume()`
    /// for safe iteration.
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

extension Buffer.Ring.Inline where Element: Copyable {
    /// Consumes the buffer's elements into a consuming view.
    ///
    /// Linearizes ring elements from inline storage to heap storage, then provides
    /// O(1)-per-element iteration via the returned view. The buffer is left empty.
    ///
    /// - Returns: A consuming view for element-by-element iteration.
    /// - Complexity: O(n) to create the view (element transfer). O(1) per element during iteration.
    @inlinable
    public mutating func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        let currentCount = header.count
        let heapStorage = Storage<Element>.Heap.create(minimumCapacity: currentCount)

        if currentCount > .zero {
            Buffer.Ring.linearize(
                header: header,
                source: storage,
                to: heapStorage
            )
        }

        // Reset inline state
        header = Buffer.Ring.Header(
            capacity: Index<Element>.Count(UInt(capacity))
        )
        storage.initialization = .empty

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
