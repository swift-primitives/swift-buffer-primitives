public import Binary_Primitives

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#elseif os(Windows)
    import WinSDK
#endif

extension Buffer {
    /// Memory utilities for platform-specific page size and alignment.
    public enum Memory {}
}

extension Buffer.Memory {
    /// Returns the system page size.
    ///
    /// - POSIX: `sysconf(_SC_PAGESIZE)`
    /// - Windows: `SYSTEM_INFO.dwPageSize`
    ///
    /// Typical values: 4096 bytes (4KB) on most systems.
    public static var pageSize: Int {
        #if os(Windows)
            var info = SYSTEM_INFO()
            GetSystemInfo(&info)
            return Int(info.dwPageSize)
        #else
            let size = sysconf(Int32(_SC_PAGESIZE))
            return size > 0 ? Int(size) : 4096
        #endif
    }

    /// Returns the system page size as a `Binary.Alignment`.
    ///
    /// Use this when creating page-aligned buffers or performing
    /// alignment operations.
    ///
    /// - Note: System page sizes are always powers of 2.
    public static var pageAlignment: Binary.Alignment {
        // Safe: system page size is always a power of 2
        try! Binary.Alignment(pageSize)
    }

    /// Returns the allocation granularity.
    ///
    /// - POSIX: Same as page size
    /// - Windows: `SYSTEM_INFO.dwAllocationGranularity` (typically 64KB)
    ///
    /// Memory mapping offsets must be aligned to this value on Windows.
    public static var granularity: Int {
        #if os(Windows)
            var info = SYSTEM_INFO()
            GetSystemInfo(&info)
            return Int(info.dwAllocationGranularity)
        #else
            return pageSize
        #endif
    }

    /// Returns the allocation granularity as a `Binary.Alignment`.
    ///
    /// Use this when aligning memory mapping offsets.
    ///
    /// - Note: Allocation granularity is always a power of 2.
    public static var granularityAlignment: Binary.Alignment {
        // Safe: allocation granularity is always a power of 2
        try! Binary.Alignment(granularity)
    }
}
