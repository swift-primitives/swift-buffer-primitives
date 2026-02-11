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
        header.initialization.forEach { range in
            source.copy(range: range, to: destination)
        }
    }
}
