extension Buffer.Linear: ExpressibleByArrayLiteral where Element: Copyable {
    // WORKAROUND: @_optimize(none) — CopyPropagation SIL ownership crash.
    // TRACKING: Research/release-mode-llvm-verifier-crash-diagnosis.md
    @_optimize(none)
    @inlinable
    public init(arrayLiteral elements: Element...) {
        var buffer = Self(minimumCapacity: .init(Cardinal(UInt(elements.count))))
        for element in elements {
            buffer.append(element)
        }
        self = buffer
    }
}
