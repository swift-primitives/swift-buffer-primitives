// MARK: - Sequence.Consume.Protocol for Ring

extension Buffer.Ring {
    /// State for consuming iteration — deinitializes remaining elements on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    public final class ConsumeState: @unchecked Sendable {
        @usableFromInline
        var header: Buffer.Ring<Element>.Header

        @usableFromInline
        let storage: Storage.Heap<Element>

        @inlinable
        package init(header: Buffer.Ring<Element>.Header, storage: Storage.Heap<Element>) {
            self.header = header
            self.storage = storage
        }

        deinit {
            var h = header
            Buffer.Ring<Element>.deinitializeAll(header: &h, storage: storage)
        }
    }
}

extension Buffer.Ring: Sequence.Consume.`Protocol` {
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        let h = header
        let s = storage
        return Sequence.Consume.View(
            state: ConsumeState(header: h, storage: s),
            next: { state in
                guard !state.header.isEmpty else { return nil }
                return Buffer.Ring<Element>.popFront(header: &state.header, storage: state.storage)
            }
        )
    }
}
