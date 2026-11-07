// Ported from gpui-pre 0.3.10: src/app.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * An event subscriber: the event type it listens to and its handler
 * (Rust: the `(TypeId, Listener)` pairs of `App::event_listeners`).
 * The handler returns `false` to unsubscribe.
 */
@:allow(glaze)
class EventListener {

    final eventType:EventType<Dynamic>;

    final handler:(Dynamic, App) -> Bool;

    function new(eventType:EventType<Dynamic>, handler:(Dynamic, App) -> Bool) {
        this.eventType = eventType;
        this.handler = handler;
    }

}
