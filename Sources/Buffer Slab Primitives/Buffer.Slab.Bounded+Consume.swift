// MARK: - Sequence.Consume.Protocol for Slab.Bounded

extension Buffer.Slab.Bounded {
    /// State for consuming iteration — deinitializes remaining occupied slots on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit. Captures the storage and a snapshot of
    /// occupied slot indices, moving elements lazily during iteration.
    @safe
    public final class ConsumeState: @unchecked Sendable {
        @usableFromInline
        let storage: Storage<Element>.Heap

        @usableFromInline
        var slots: [Bit.Index]

        @usableFromInline
        var position: Int

        @inlinable
        package init(storage: Storage<Element>.Heap, slots: [Bit.Index]) {
            self.storage = storage
            self.slots = slots
            self.position = 0
        }

        deinit {
            // Deinitialize any remaining elements not yet consumed
            while position < slots.count {
                storage.deinitialize(at: slots[position].retag(Element.self))
                position += 1
            }
            storage.initialization = .empty
        }
    }
}

extension Buffer.Slab.Bounded: Sequence.Consume.`Protocol` {
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        // Snapshot occupied slot indices before consuming
        var slots: [Bit.Index] = []
        header.bitmap.ones.forEach { bitIndex in
            slots.append(bitIndex)
            header.bitmap[bitIndex] = false
        }
        let state = ConsumeState(storage: storage, slots: slots)
        return Sequence.Consume.View(
            state: state,
            next: { state in
                guard state.position < state.slots.count else { return nil }
                let element = state.storage.move(at: state.slots[state.position].retag(Element.self))
                state.position += 1
                return element
            }
        )
    }
}
