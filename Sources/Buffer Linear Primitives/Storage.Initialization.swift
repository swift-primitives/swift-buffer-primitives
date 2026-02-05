//
//  File.swift
//  swift-buffer-primitives
//
//  Created by Coen ten Thije Boonkkamp on 04/02/2026.
//

public import Storage_Primitives

extension Storage.Initialization where Element: ~Copyable {
    @inlinable
    public init(
        _ header: Buffer<Element>.Linear.Header
    ) {
        if header.count == .zero {
            self = .empty
            return
        }
        let end = Index<Element>(header.count)
        self = .one(.zero ..< end)
    }
}
