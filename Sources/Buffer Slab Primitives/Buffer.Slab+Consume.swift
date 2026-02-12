// MARK: - Sequence.Consume.Protocol for Slab

extension Buffer.Slab {
    /// State for consuming iteration — deinitializes remaining occupied slots on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit. The bitmap IS the consume state —
    /// linear scan provides destructive iteration through occupied slots.
    @safe
    public final class ConsumeState: @unchecked Sendable {
        @usableFromInline
        let storage: Storage<Element>.Heap

        @usableFromInline
        var bitmap: Bit.Vector.Bounded

        @inlinable
        package init(storage: Storage<Element>.Heap, bitmap: consuming Bit.Vector.Bounded) {
            self.storage = storage
            self.bitmap = bitmap
        }

        deinit {
            bitmap.ones.forEach { slot in
                storage.deinitialize(at: slot.retag(Element.self))
            }
            storage.initialization = .empty
        }
    }
}

extension Buffer.Slab: Sequence.Consume.`Protocol` {
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        let state = ConsumeState(storage: storage, bitmap: header.bitmap.take())
        return Sequence.Consume.View(
            state: state,
            next: { state in
                var slot: Bit.Index = .zero
                while slot < state.bitmap.count {
                    if state.bitmap[slot] {
                        state.bitmap[slot] = false
                        return state.storage.move(at: slot.retag(Element.self))
                    }
                    slot += .one
                }
                return nil
            }
        )
    }
}
