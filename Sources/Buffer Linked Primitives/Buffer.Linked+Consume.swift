public import Buffer_Primitives_Core

// MARK: - Sequence.Consume support for Linked

extension Buffer.Linked where Element: ~Copyable {
    /// State for consuming iteration — deinitializes remaining elements on early exit.
    ///
    /// Class-based because `Sequence.Consume.Protocol.ConsumeState` must be Copyable,
    /// and cleanup-on-drop requires a deinit.
    ///
    /// Holds the pool storage and traverses the link chain front-to-back.
    /// On early exit, deinit traverses remaining nodes and deallocates them.
    public final class ConsumeState: @unsafe @unchecked Sendable {
        @usableFromInline
        let storage: Storage<Node>.Pool

        @usableFromInline
        var current: Index<Node>

        @usableFromInline
        let sentinel: Index<Node>

        @inlinable
        package init(
            storage: Storage<Node>.Pool,
            current: Index<Node>,
            sentinel: Index<Node>
        ) {
            self.storage = storage
            self.current = current
            self.sentinel = sentinel
        }

        deinit {
            while current != sentinel {
                let node = unsafe storage.pointer(at: current).move()
                let next = node.links[0]
                try! storage.deallocate(at: current)
                current = next
            }
        }
    }
}

extension Buffer.Linked: Sequence.Consume.`Protocol` where Element: Copyable {
    @inlinable
    public consuming func consume() -> Sequence.Consume.View<Element, ConsumeState> {
        let sentinel = header.sentinel
        let storage = storage
        let head = header.head
        return Sequence.Consume.View(
            state: ConsumeState(storage: storage, current: head, sentinel: sentinel),
            next: { state in
                guard state.current != state.sentinel else { return nil }
                let node = unsafe state.storage.pointer(at: state.current).move()
                let next = node.links[0]
                try! state.storage.deallocate(at: state.current)
                state.current = next
                return node.element
            }
        )
    }
}
