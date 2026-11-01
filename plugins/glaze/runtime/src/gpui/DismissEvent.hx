// Ported from gpui-pre 0.3.10: src/window.rs (DismissEvent)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Emitted by implementers of `ManagedView` to indicate the view should be
 * dismissed, such as when a view is presented as a modal.
 *
 * Rust's unit struct: emit `DismissEvent.instance` (or `new DismissEvent()`),
 * subscribe with `cx.subscribe(entity, DismissEvent, ...)`.
 */
class DismissEvent {

    public static final instance:DismissEvent = new DismissEvent();

    public function new() {}

}
