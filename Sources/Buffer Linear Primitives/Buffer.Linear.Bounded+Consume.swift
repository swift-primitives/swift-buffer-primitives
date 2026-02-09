// MARK: - Sequence.Consume.Protocol for Linear.Bounded

extension Buffer.Linear.Bounded where Element: ~Copyable {
    /// State for consuming iteration — deinitializes remaining elements on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    public final class ConsumeState: @unchecked Sendable {
        @usableFromInline
        let header: Buffer.Linear.Header

        @usableFromInline
        let storage: Storage<Element>.Heap

        @usableFromInline
        var position: UInt

        @inlinable
        package init(header: Buffer.Linear.Header, storage: Storage<Element>.Heap) {
            self.header = header
            self.storage = storage
            self.position = 0
        }

        deinit {
            // Deinitialize remaining elements from current position to count
            var current = Index<Element>.Count(Cardinal(position))
            while current < header.count {
                storage.deinitialize(at: current.map(Ordinal.init))
                current = current.add.saturating(.one)
            }
            storage.initialization = .empty
        }
    }
}

extension Buffer.Linear.Bounded: Sequence.Consume.`Protocol` where Element: Copyable {
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        let h = header
        let s = storage
        return Sequence.Consume.View(
            state: ConsumeState(header: h, storage: s),
            next: { state in
                let current = Index<Element>.Count(Cardinal(state.position))
                guard current < state.header.count else { return nil }
                let element = state.storage.move(at: current.map(Ordinal.init))
                state.position &+= 1
                return element
            }
        )
    }
}
