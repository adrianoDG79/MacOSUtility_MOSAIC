/// Marker for events published on the ``EventBus``.
public protocol MosaicEvent: Sendable {}

/// Typed publish/subscribe channel between modules (MOS-ARCH-001 §4.3).
///
/// Modules never import each other: a module publishes, say, `VolumeMounted`
/// and any interested module subscribes to that type. Each subscription is an
/// `AsyncStream` that ends when the subscriber stops iterating.
public actor EventBus {
    private var sinks: [ObjectIdentifier: [MosaicID: @Sendable (any MosaicEvent) -> Void]] = [:]

    public init() {}

    public func subscribe<Event: MosaicEvent>(
        _ type: Event.Type,
        bufferingPolicy: AsyncStream<Event>.Continuation.BufferingPolicy = .bufferingNewest(256)
    ) -> AsyncStream<Event> {
        let key = ObjectIdentifier(type)
        let token = MosaicID.generate()
        let (stream, continuation) = AsyncStream<Event>.makeStream(bufferingPolicy: bufferingPolicy)
        sinks[key, default: [:]][token] = { event in
            if let event = event as? Event {
                continuation.yield(event)
            }
        }
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSink(key: key, token: token) }
        }
        return stream
    }

    public func publish<Event: MosaicEvent>(_ event: Event) {
        guard let eventSinks = sinks[ObjectIdentifier(Event.self)] else { return }
        for sink in eventSinks.values {
            sink(event)
        }
    }

    public func subscriberCount<Event: MosaicEvent>(for type: Event.Type) -> Int {
        sinks[ObjectIdentifier(type)]?.count ?? 0
    }

    private func removeSink(key: ObjectIdentifier, token: MosaicID) {
        sinks[key]?[token] = nil
        if sinks[key]?.isEmpty == true {
            sinks[key] = nil
        }
    }
}
