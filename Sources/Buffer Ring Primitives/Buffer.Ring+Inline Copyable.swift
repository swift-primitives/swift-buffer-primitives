// MARK: - Static Operations for Copyable Elements on Storage.Inline

extension Buffer.Ring {

    /// Copies all elements from source inline storage to destination heap storage in logical order.
    ///
    /// After this call, destination contains elements at slots `0 ..< header.count`
    /// in FIFO order (linearized).
    @inlinable
    public static func linearize<Element: Copyable, let capacity: Int>(
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
        case .two(let first, let second):
            var dstSlot: Index<Storage> = .zero
            var srcSlot = first.lowerBound
            while srcSlot < first.upperBound {
                let value: Element = unsafe source.pointer(at: srcSlot).pointee
                destination.initialize(to: value, at: dstSlot)
                srcSlot = srcSlot.successor.saturating()
                dstSlot = dstSlot.successor.saturating()
            }
            srcSlot = second.lowerBound
            while srcSlot < second.upperBound {
                let value: Element = unsafe source.pointer(at: srcSlot).pointee
                destination.initialize(to: value, at: dstSlot)
                srcSlot = srcSlot.successor.saturating()
                dstSlot = dstSlot.successor.saturating()
            }
        }
    }

    /// Copies all ring elements from inline to heap storage, linearized to slots `0 ..< count`.
    @inlinable
    public static func copy<Element: Copyable, let capacity: Int>(
        header: Header,
        source: borrowing Storage.Inline<Element, capacity>,
        to destination: Storage.Heap<Element>
    ) {
        linearize(header: header, source: source, to: destination)
    }
}
