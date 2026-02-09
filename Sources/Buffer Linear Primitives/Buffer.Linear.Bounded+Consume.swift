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
        var position: Index<Element>

        @inlinable
        package init(header: Buffer.Linear.Header, storage: Storage<Element>.Heap) {
            self.header = header
            self.storage = storage
            self.position = .zero
        }

        deinit {
            while position < header.count {
                storage.deinitialize(at: position)
                position += .one
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
                guard state.position < state.header.count else { return nil }
                let element = state.storage.move(at: state.position)
                state.position += .one
                return element
            }
        )
    }
}
