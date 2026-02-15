import Finite_Primitives

// MARK: - Subscript for Linear.Inline (~Copyable)

extension Buffer.Linear.Inline where Element: ~Copyable {
    /// Accesses the element at the given index.
    ///
    /// - Parameter index: The index of the element to access.
    @inlinable
    public subscript(index: Index<Element>) -> Element {
        _read {
            let bounded = Index<Element>.Bounded<capacity>(index)!
            yield unsafe storage.pointer(at: bounded).pointee
        }
        _modify {
            let bounded = Index<Element>.Bounded<capacity>(index)!
            yield unsafe &storage.pointer(at: bounded).pointee
        }
    }

    /// Accesses the element at a capacity-bounded index.
    ///
    /// The bounded index guarantees `index < capacity` at the type level.
    /// Only the `index < count` check remains as a runtime precondition
    /// (the slot must be initialized).
    ///
    /// - Parameter index: A capacity-bounded index.
    @inlinable
    public subscript(index: Index<Element>.Bounded<capacity>) -> Element {
        _read {
            yield unsafe storage.pointer(at: index).pointee
        }
        _modify {
            yield unsafe &storage.pointer(at: index).pointee
        }
    }
}
