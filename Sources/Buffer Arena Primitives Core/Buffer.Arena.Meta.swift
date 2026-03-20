extension Buffer.Arena where Element: ~Copyable {
    // MARK: - Meta

    /// Per-slot metadata: generation token + free-list link.
    ///
    /// Canonical definition lives at `Storage<Element>.Arena.Meta`.
    public typealias Meta = Storage<Element>.Arena.Meta
}
