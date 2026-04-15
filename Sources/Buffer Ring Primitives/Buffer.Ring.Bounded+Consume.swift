// MARK: - Sequence.Consume.Protocol for Ring.Bounded

extension Buffer.Ring.Bounded where Element: ~Copyable {
    /// State for consuming iteration — deinitializes remaining elements on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    public final class ConsumeState: @unsafe @unchecked Sendable {
        @usableFromInline
        var header: Buffer.Ring.Header

        @usableFromInline
        let storage: Storage<Element>.Heap

        @inlinable
        package init(
            header: Buffer.Ring.Header,
            storage: Storage<Element>.Heap
        ) {
            self.header = header
            self.storage = storage
        }

        deinit {
            var h = header
            Buffer.Ring.deinitializeAll(header: &h, storage: storage)
        }
    }
}

extension Buffer.Ring.Bounded: Sequence.Consume.`Protocol` where Element: Copyable {
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        let header = header
        let storage = storage
        return Sequence.Consume.View(
            state: ConsumeState(header: header, storage: storage),
            next: { state in
                guard !state.header.isEmpty else { return nil }
                return Buffer.Ring.popFront(header: &state.header, storage: state.storage)
            }
        )
    }
}
