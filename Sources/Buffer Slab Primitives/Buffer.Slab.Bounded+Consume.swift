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
        let storage: Storage.Heap<Element>

        @usableFromInline
        var slots: [UInt]

        @usableFromInline
        var position: Int

        @inlinable
        package init(storage: Storage.Heap<Element>, slots: [UInt]) {
            self.storage = storage
            self.slots = slots
            self.position = 0
        }

        deinit {
            // Deinitialize any remaining elements not yet consumed
            while position < slots.count {
                let storageIndex = Index<Storage>(Ordinal(slots[position]))
                storage.deinitialize(at: storageIndex)
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
        var slots: [UInt] = []
        header.bitmap.ones.forEach { bitIndex in
            slots.append(bitIndex.rawValue.rawValue)
            header.bitmap[bitIndex] = false
        }
        let state = ConsumeState(storage: storage, slots: slots)
        return Sequence.Consume.View(
            state: state,
            next: { state in
                guard state.position < state.slots.count else { return nil }
                let storageIndex = Index<Storage>(Ordinal(state.slots[state.position]))
                let element = state.storage.move(at: storageIndex)
                state.position += 1
                return element
            }
        )
    }
}
