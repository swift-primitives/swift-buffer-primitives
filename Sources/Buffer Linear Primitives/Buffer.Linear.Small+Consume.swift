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
        switch _storage {
        case .heap(var heap):
            let header = heap.header
            let storage = heap.storage
            // Clear heap header so deinit is no-op, then reinitialize as inline
            heap.header.count = .zero
            heap.storage.initialization = .empty
            self = Self(_storage: .inline(Buffer<Element>.Linear.Inline<inlineCapacity>()))
            _ = consume heap
            return Sequence.Consume.View(
                state: ConsumeState(storage: storage, count: header.count),
                next: { state in
                    guard state.position < state.count else { return nil }
                    let element = state.storage.move(at: state.position)
                    state.position += .one
                    return element
                }
            )
        case .inline(var buf):
            let currentCount = buf.count
            let heapStorage = Storage<Element>.Heap.create(minimumCapacity: currentCount)

            if currentCount > .zero {
                let end = currentCount.map(Ordinal.init)
                buf.storage.move(range: .zero ..< end, to: heapStorage)
                heapStorage.initialization = .one(.zero ..< end)
            }

            buf.header.count = .zero
            buf.storage.initialization = .empty
            self = Self(_storage: .inline(consume buf))

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
