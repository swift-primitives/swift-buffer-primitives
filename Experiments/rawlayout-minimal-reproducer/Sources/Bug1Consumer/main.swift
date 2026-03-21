// Bug1Consumer: executable target that depends on Bug1Middleware
//
// Build: rm -rf .build && swift build -c release --target Bug1Consumer
// Expected: signal 6, "Instruction does not dominate all uses!"
//
// NOTE: The crash occurs when compiling Bug1Middleware, not this consumer.
// Building Bug1Middleware alone also crashes:
//   rm -rf .build && swift build -c release --target Bug1Middleware

public import Bug1Core
public import Bug1Middleware

let buf = Buffer<Int>()
print("Bug1: Buffer<Int> created — should not reach here in release mode")
