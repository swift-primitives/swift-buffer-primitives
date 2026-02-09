// MARK: - Sequence.Consume support for Linear.Inline

extension Buffer.Linear.Inline where Element: ~Copyable {
    /// State for consuming iteration — deinitializes remaining elements on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    ///
    /// Elements are moved from inline storage to heap storage during `consume()`
    /// for safe iteration. This introduces a heap allocation but preserves
    /// O(1)-per-element extraction per [CONSUME-001].
    public final class ConsumeState: @unchecked Sendable {
        @usableFromInline
        let storage: Storage<Element>.Heap

        @usableFromInline
        var position: Index<Element>

        @usableFromInline
        let count: Index<Element>.Count

        @inlinable
        package init(storage: Storage<Element>.Heap, count: Index<Element>.Count) {
            self.storage = storage
            self.position = .zero
            self.count = count
        }

        deinit {
            while position < count {
                storage.deinitialize(at: position)
                position += .one
            }
            storage.initialization = .empty
        }
    }
}

extension Buffer.Linear.Inline where Element: Copyable {
    /// Consumes the buffer's elements into a consuming view.
    ///
    /// Moves all elements from inline storage to heap storage, then provides
    /// O(1)-per-element iteration via the returned view. The buffer is left empty.
    ///
    /// - Returns: A consuming view for element-by-element iteration.
    /// - Complexity: O(n) to create the view (element transfer). O(1) per element during iteration.
    @inlinable
    public mutating func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        let currentCount = header.count
        let heapStorage = Storage<Element>.Heap.create(minimumCapacity: currentCount)

        if currentCount > .zero {
            let end = currentCount.map(Ordinal.init)
            storage.move(range: .zero ..< end, to: heapStorage)
            heapStorage.initialization = .one(.zero ..< end)
        }

        header.count = .zero
        storage.initialization = .empty

        return Sequence.Consume.View(
            state: ConsumeState(storage: heapStorage, count: currentCount),
            next: { state in
                guard state.position < state.count else { return nil }
                let element = state.storage.move(at: state.position)
                state.position += .one
                return element
            }
        )
    }
}
