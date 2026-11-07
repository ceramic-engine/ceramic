// Ported from gpui-pre 0.3.10: src/app/async_context.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * An app context that can be held across await points (task continuations).
 * Without Rust's borrow rules, it is simply the `App`: `cx.update(...)`,
 * `entity.update(cx, ...)`, `weak.update(cx, ...)`, `cx.spawn(...)`,
 * `cx.backgroundExecutor()` and the globals methods work the same way.
 */
typedef AsyncApp = App;
