// MARK: - Static Operations for Copyable Elements on Storage.Inline

extension Buffer.Linear where Element: Copyable {

    /// Copies elements from inline source storage to heap destination storage.
    ///
    /// After this call, destination contains elements at slots `0 ..< header.count`.
    @inlinable
    public static func copy<let capacity: Int>(
        header: Header,
        source: borrowing Storage<Element>.Inline<capacity>,
        to destination: Storage<Element>.Heap
    ) {
        switch header.initialization {
        case .empty:
            break
        case .one(let range):
            var dstSlot: Index<Element> = .zero
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
