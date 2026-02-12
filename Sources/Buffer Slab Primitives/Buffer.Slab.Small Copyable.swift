// MARK: - Copyable Conformances for Slab.Small
//
// Note: Slab.Small is NEVER Copyable (contains Inline which has @_rawLayout storage).
// This file provides read-only accessors for Copyable elements.

extension Buffer.Slab.Small where Element: Copyable {

    /// Reads the element at the given slot without removing it.
    ///
    /// - Precondition: The slot is occupied.
    @inlinable
    public func peek(at slot: Bit.Index) -> Element {
        switch _heapBuffer {
        case .some(let heap):
            return unsafe heap.storage.pointer(at: slot.retag(Element.self)).pointee
        case .none:
            return _inlineBuffer.peek(at: slot)
        }
    }
}
