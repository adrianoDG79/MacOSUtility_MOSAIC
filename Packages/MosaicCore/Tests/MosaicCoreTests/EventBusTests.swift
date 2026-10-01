import Testing
@testable import MosaicCore

private struct VolumeMounted: MosaicEvent, Equatable {
    let name: String
}

private struct SourceStatusChanged: MosaicEvent, Equatable {
    let source: String
}

struct EventBusTests {
    @Test func deliversEventsOnlyToSubscribersOfThatType() async {
        let bus = EventBus()
        let volumes = await bus.subscribe(VolumeMounted.self)
        let sources = await bus.subscribe(SourceStatusChanged.self)

        await bus.publish(VolumeMounted(name: "BackUpDisk"))
        await bus.publish(SourceStatusChanged(source: "Download"))

        var volumeIterator = volumes.makeAsyncIterator()
        var sourceIterator = sources.makeAsyncIterator()
        #expect(await volumeIterator.next() == VolumeMounted(name: "BackUpDisk"))
        #expect(await sourceIterator.next() == SourceStatusChanged(source: "Download"))
    }

    @Test func deliversTheSameEventToEverySubscriber() async {
        let bus = EventBus()
        let first = await bus.subscribe(VolumeMounted.self)
        let second = await bus.subscribe(VolumeMounted.self)

        await bus.publish(VolumeMounted(name: "NAS"))

        var firstIterator = first.makeAsyncIterator()
        var secondIterator = second.makeAsyncIterator()
        #expect(await firstIterator.next()?.name == "NAS")
        #expect(await secondIterator.next()?.name == "NAS")
    }

    @Test func forgetsSubscribersThatStopListening() async throws {
        let bus = EventBus()
        let task = Task {
            for await _ in await bus.subscribe(VolumeMounted.self) {}
        }
        try await waitUntil { await bus.subscriberCount(for: VolumeMounted.self) == 1 }
        task.cancel()
        try await waitUntil { await bus.subscriberCount(for: VolumeMounted.self) == 0 }
    }
}

/// Polls `condition` until it holds, failing after about two seconds.
func waitUntil(_ condition: () async -> Bool) async throws {
    for _ in 0..<200 {
        if await condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Condition not met within two seconds")
}
