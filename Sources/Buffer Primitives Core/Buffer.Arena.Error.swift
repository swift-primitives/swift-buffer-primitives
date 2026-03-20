extension Buffer.Arena where Element: ~Copyable {
    // MARK: - Error

    /// Errors that can occur during arena buffer operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// A `Position` handle refers to a freed or never-allocated slot.
        case invalidPosition
    }
}
