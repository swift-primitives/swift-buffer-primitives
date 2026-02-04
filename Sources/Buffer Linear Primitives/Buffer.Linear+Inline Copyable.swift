// MARK: - Static Operations for Copyable Elements on Storage.Inline

extension Buffer.Linear {

    /// Copies elements from inline source storage to heap destination storage.
    ///
    /// After this call, destination contains elements at slots `0 ..< header.count`.
    @inlinable
    public static func copy<Element: Copyable, let capacity: Int>(
        header: Header,
        source: borrowing Storage.Inline<Element, capacity>,
        to destination: Storage.Heap<Element>
    ) {
        switch header.initialization {
        case .empty:
            break
        case .one(let range):
            var dstSlot: Index<Storage> = .zero
            var srcSlot = range.lowerBound
            while srcSlot < range.upperBound {
                let value: Element = unsafe source.pointer(at: srcSlot).pointee
                destination.initialize(to: value, at: dstSlot)
                srcSlot = srcSlot.successor.saturating()
                dstSlot = dstSlot.successor.saturating()
            }
        case .two(_, _):
            // Linear buffers never have .two
            break
        }
    }
}
