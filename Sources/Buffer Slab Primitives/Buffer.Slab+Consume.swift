// MARK: - Sequence.Consume.Protocol for Slab

extension Buffer.Slab {
    /// State for consuming iteration — deinitializes remaining occupied slots on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit. The bitmap IS the consume state —
    /// `pop.first()` provides destructive iteration through occupied slots.
    @safe
    public final class ConsumeState: @unchecked Sendable {
        @usableFromInline
        let storage: Storage<Element>.Heap

        @usableFromInline
        var bitmap: Bit.Vector

        @inlinable
        package init(storage: Storage<Element>.Heap, bitmap: consuming Bit.Vector) {
            self.storage = storage
            self.bitmap = bitmap
        }

        deinit {
            while let slot = bitmap.pop.first() {
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
                guard let slot = state.bitmap.pop.first() else { return nil }
                return state.storage.move(at: slot.retag(Element.self))
            }
        )
    }
}
