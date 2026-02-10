//
//  File.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

import Buffer_Primitives_Core
import Storage_Primitives

extension Storage.Initialization where Element: ~Copyable {
    @inlinable
    public init(
        _ header: Buffer<Element>.Ring.Header
    ) {
        if header.count == .zero {
            self = .empty
            return
        }

        let tail = header.head + header.count

        if tail <= header.capacity {
            self = .one(header.head ..< tail)
        } else {
            self = .two(
                first: header.head ..< header.capacity.map(Ordinal.init),
                second: .zero ..< Index<Element>.Count(tail).subtract.saturating(header.capacity).map(Ordinal.init)
            )
        }
    }
}

// MARK: - forEach per [IMPL-031]

extension Storage.Initialization where Element: ~Copyable {
    /// Calls `body` with each initialized range.
    ///
    /// Per [IMPL-031], enums with uniform operations provide `.forEach`.
    @inlinable
    public func forEach(_ body: (Range<Index<Element>>) -> Void) {
        switch self {
        case .empty: break
        case .one(let range): body(range)
        case .two(let first, let second):
            body(first)
            body(second)
        }
    }
}

extension Storage.Initialization where Element: ~Copyable {
    @inlinable
    public init<let capacity: Int>(
        _ header: Buffer<Element>.Ring.Header.Cyclic<capacity>
    ) {
        if header.count == .zero {
            self = .empty
            return
        }

        let slotCapacity = Buffer<Element>.Ring.Header.Cyclic<capacity>.slotCapacity
        let headIndex = header.head.map { $0.position }
        let tail = headIndex + header.count

        if tail <= slotCapacity {
            self = .one(headIndex ..< tail)
        } else {
            self = .two(
                first: headIndex ..< slotCapacity.map(Ordinal.init),
                second: .zero ..< Index<Element>.Count(tail).subtract.saturating(slotCapacity).map(Ordinal.init)
            )
        }
    }
}
