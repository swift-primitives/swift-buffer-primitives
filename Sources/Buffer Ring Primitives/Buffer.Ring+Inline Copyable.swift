// MARK: - Static Operations for Copyable Elements on Storage.Inline

extension Buffer.Ring where Element: Copyable {

    /// Copies all elements from source inline storage to destination heap storage in logical order.
    ///
    /// After this call, destination contains elements at slots `0 ..< header.count`
    /// in FIFO order (linearized).
    @inlinable
    public static func linearize<let capacity: Int>(
        header: Header,
        source: borrowing Storage<Element>.Inline<capacity>,
        to destination: Storage<Element>.Heap
    ) {
        header.initialization.linearize { range, offset in
            var srcSlot = range.lowerBound
            var dstSlot = offset
            while srcSlot < range.upperBound {
                let bounded = Index<Element>.Bounded<capacity>(srcSlot)!
                let ptr: UnsafePointer<Element> = unsafe source.pointer(at: bounded)
                let value: Element = unsafe ptr.pointee
                destination.initialize(to: value, at: dstSlot)
                srcSlot = srcSlot.successor.saturating()
                dstSlot = dstSlot.successor.saturating()
            }
        }
    }

    /// Copies all ring elements from inline to heap storage, linearized to slots `0 ..< count`.
    @inlinable
    public static func copy<let capacity: Int>(
        header: Header,
        source: borrowing Storage<Element>.Inline<capacity>,
        to destination: Storage<Element>.Heap
    ) {
        linearize(header: header, source: source, to: destination)
    }
}
