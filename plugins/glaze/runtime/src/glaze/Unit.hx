// Ported from gpui-pre 0.3.10: src/executor.rs
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze;

/**
 * The value of a task that produces nothing (Rust: `()`, as in `Task<()>`).
 *
 * Never use `Task<Void>`: hxcpp cannot compile a callback taking a `Void`
 * argument, so `Task<Void>.then(_ -> ...)` would only fail on native targets.
 *
 * The value is `Unit.unit` (lower case: `Unit.Unit` would resolve to the type).
 */
#if cs
/*
 * On C#, the value of a `Task<T>` is held as an object: an abstract over Int
 * would be boxed (an allocation) each time a task is given `Unit.unit`. Over a
 * class, it is one shared instance.
 */
abstract Unit(UnitValue) {

    public static final unit:Unit = cast UnitValue.value;

}

private class UnitValue {

    public static final value = new UnitValue();

    function new() {}

}
#else
enum abstract Unit(Int) {

    var unit = 0;

}
#end
