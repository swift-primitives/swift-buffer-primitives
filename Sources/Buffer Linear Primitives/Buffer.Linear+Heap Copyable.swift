// MARK: - Static Operations for Copyable Elements on Storage.Heap

extension Buffer.Linear where Element: Copyable {

    /// Copies elements from source storage to destination storage.
    ///
    /// After this call, destination contains elements at slots `0 ..< header.count`.
    @inlinable
    public static func copy(
        header: Header,
        source: Storage<Element>.Heap,
        to destination: Storage<Element>.Heap
    ) {
        switch header.initialization {
        case .empty:
            break
        case .one(let range):
            source.copy(range: range, to: destination)
        case .two(_, _):
            // Linear buffers never have .two
            break
        }
    }
}
