// MARK: - Sequence.Consume support for Linear.Small

extension Buffer.Linear.Small where Element: ~Copyable {
    /// State for consuming iteration — deinitializes remaining elements on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    ///
    /// Elements are always moved to heap storage for safe iteration.
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

extension Buffer.Linear.Small where Element: Copyable {
    /// Consumes the buffer's elements into a consuming view.
    ///
    /// If in heap mode, takes the heap storage directly.
    /// If in inline mode, moves elements to heap storage first.
    /// The buffer is left empty in inline mode.
    ///
    /// - Returns: A consuming view for element-by-element iteration.
    @inlinable
    public mutating func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        if _heapBuffer != nil {
            let header = heap.header
            let storage = heap.storage
            _heapBuffer = nil
            return Sequence.Consume.View(
                state: ConsumeState(storage: storage, count: header.count),
                next: { state in
                    guard state.position < state.count else { return nil }
                    let element = state.storage.move(at: state.position)
                    state.position += .one
                    return element
                }
            )
        } else {
            let currentCount = _inlineBuffer.count
            let heapStorage = Storage<Element>.Heap.create(minimumCapacity: currentCount)

            if currentCount > .zero {
                let end = currentCount.map(Ordinal.init)
                _inlineBuffer.storage.move(range: .zero ..< end, to: heapStorage)
                heapStorage.initialization = .one(.zero ..< end)
            }

            _inlineBuffer.header.count = .zero
            _inlineBuffer.storage.initialization = .empty

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
}
