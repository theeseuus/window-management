import Foundation

// Accessibility frame setters can return before the application's animation
// finishes. Serialize changes using observed frames, not setter return alone.
@MainActor
enum DirectFrameApplication {
    enum Change { case position, size }
    static func apply(target: Frame, from original: Frame,
                      check: () throws -> Void,
                      read: () throws -> Frame,
                      write: (Change, Frame) throws -> Void,
                      pause: () async throws -> Void = { try await Task.sleep(for:.milliseconds(40)) }) async throws -> Frame {
        func settle() async throws {
            var previous = try read(), stable = 0
            // At least 400 ms, then three unchanged samples; bounded at 1.2 seconds.
            // Keep checking the captured focus and Space throughout the wait.
            for tick in 1...30 {
                try await pause(); try Task.checkCancellation(); try check()
                let current = try read()
                stable = current.matches(previous,tolerance:0.1) ? stable+1 : 0
                previous = current
                if tick >= 10 && stable >= 3 { return }
            }
        }
        func change(_ kind: Change) async throws {
            try Task.checkCancellation(); try check(); try write(kind,target)
            try await settle()
        }
        let resizing = abs(original.w-target.w)>2 || abs(original.h-target.h)>2
        // Moving first makes room for growth from low/right starting positions.
        // The old size can constrain that move, so position again after resizing.
        try await change(.position)
        if resizing {
            try await change(.size)
            try await change(.position)
        }
        try check()
        return try read()
    }
}
