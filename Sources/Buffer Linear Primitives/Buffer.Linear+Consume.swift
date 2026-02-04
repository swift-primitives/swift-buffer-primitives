// MARK: - Sequence.Consume.Protocol for Linear

extension Buffer.Linear {
    /// State for consuming iteration — deinitializes remaining elements on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    public final class ConsumeState: @unchecked Sendable {
        @usableFromInline
        let header: Buffer.Linear.Header

        @usableFromInline
        let storage: Storage.Heap<Element>

        @usableFromInline
        var position: UInt

        @inlinable
        package init(header: Buffer.Linear.Header, storage: Storage.Heap<Element>) {
            self.header = header
            self.storage = storage
            self.position = 0
        }

        deinit {
            // Deinitialize remaining elements from current position to count
            let count = header.count.rawValue.rawValue
            while position < count {
                let idx = Index<Storage>(Ordinal(position))
                storage.deinitialize(at: idx)
                position &+= 1
            }
            storage.initialization = .empty
        }
    }
}

extension Buffer.Linear: Sequence.Consume.`Protocol` {
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        let h = header
        let s = storage
        return Sequence.Consume.View(
            state: ConsumeState(header: h, storage: s),
            next: { state in
                guard state.position < state.header.count.rawValue.rawValue else { return nil }
                let idx = Index<Storage>(Ordinal(state.position))
                let element = state.storage.move(at: idx)
                state.position &+= 1
                return element
            }
        )
    }
}
