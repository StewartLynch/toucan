import Foundation
import ArgumentParser
import Dispatch
import EonilFSEvents
import ToucanSDK

// TODO: use async sequence for file watcher + Linux support
let semaphore = DispatchSemaphore(value: 0)
private var lastGenerationTime: Date?

func waitForever() {
    semaphore.wait()
}

extension Entrypoint {

    struct Watch: AsyncParsableCommand {

        static var _commandName: String = "watch"

        @Argument(help: "The input directory (default: src).")
        var input: String = "./src"

        @Argument(help: "The output directory (default: docs).")
        var output: String = "./docs"

        @Option(name: .shortAndLong, help: "The base url to use.")
        var baseUrl: String? = nil

        mutating func run() async throws {
            let toucan = Toucan(
                input: input,
                output: output,
                baseUrl: baseUrl
            )
            try toucan.generate()

            let eventStream = try EonilFSEventStream(
                pathsToWatch: [input],
                sinceWhen: .now,
                latency: 0,
                flags: [],
                handler: { event in
                    guard let flag = event.flag, flag == [] else {
                        return
                    }
                    let now = Date()
                    let last = lastGenerationTime ?? now
                    let diff = abs(last.timeIntervalSince(now))
                    // 3 sec delay
                    guard (diff == 0) || (diff > 3) else {
                        return
                    }

                    print("Generating site...")
                    do {
                        try toucan.generate()
                        lastGenerationTime = now
                    }
                    catch {
                        print("\(error)")
                    }
                    print("Site re-generated.")
                }
            )

            eventStream.setDispatchQueue(DispatchQueue.main)

            try eventStream.start()
            print("👀 Watching: `\(input)` -> \(output).")

            waitForever()
        }
    }
}