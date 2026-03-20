extension Buffer.Ring.Bounded {
    /// Errors that can occur during bounded ring buffer operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The number of elements exceeds the buffer's capacity.
        case capacityExceeded
    }
}
