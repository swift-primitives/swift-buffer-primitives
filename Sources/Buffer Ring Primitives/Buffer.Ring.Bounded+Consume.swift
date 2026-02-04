// MARK: - Sequence.Consume.Protocol for Ring.Bounded

extension Buffer.Ring.Bounded {
    /// State for consuming iteration — deinitializes remaining elements on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    public final class ConsumeState: @unchecked Sendable {
        @usableFromInline
        var header: Buffer.Ring.Header

        @usableFromInline
        let storage: Storage.Heap<Element>

        @inlinable
        package init(header: Buffer.Ring.Header, storage: Storage.Heap<Element>) {
            self.header = header
            self.storage = storage
        }

        deinit {
            var h = header
            Buffer<Element>.Ring.deinitializeAll(header: &h, storage: storage)
        }
    }
}

extension Buffer.Ring.Bounded: Sequence.Consume.`Protocol` {
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        let h = header
        let s = storage
        return Sequence.Consume.View(
            state: ConsumeState(header: h, storage: s),
            next: { state in
                guard !state.header.isEmpty else { return nil }
                return Buffer<Element>.Ring.popFront(header: &state.header, storage: state.storage)
            }
        )
    }
}
