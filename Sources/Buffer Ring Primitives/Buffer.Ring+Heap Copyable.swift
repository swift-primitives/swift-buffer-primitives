// MARK: - Static Operations for Copyable Elements on Storage.Heap

extension Buffer.Ring where Element: Copyable {

    /// Copies all elements from source to destination storage in logical order.
    ///
    /// After this call, destination contains elements at slots `0 ..< header.count`
    /// in FIFO order (linearized).
    @inlinable
    public static func linearize(
        header: Header,
        source: Storage<Element>.Heap,
        to destination: Storage<Element>.Heap
    ) {
        header.initialization.linearize { range, offset in
            source.copy(range: range, to: destination, at: offset)
        }
    }

    /// Copies all ring elements to a new storage, linearized to slots `0 ..< count`.
    @inlinable
    public static func copy(
        header: Header,
        source: Storage<Element>.Heap,
        to destination: Storage<Element>.Heap
    ) {
        linearize(header: header, source: source, to: destination)
    }
}
