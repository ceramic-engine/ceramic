// Ported from gpui-pre 0.3.10: src/executor.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * State of a `Task`. Rust futures have no observable state: this replaces
 * polling (`Pending` / `Ready`), `Result::Err` (`Failed`) and dropping (`Cancelled`).
 */
enum abstract TaskState(Int) {

    var Pending = 0;

    var Ready = 1;

    var Failed = 2;

    var Cancelled = 3;

}
