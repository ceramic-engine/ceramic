// Ported from gpui-kit 0.8.1: crates/component/src/sizing.rs (Sizable)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit;

/**
 * A trait for setting the size of an element (`Size.Medium` by default).
 *
 * Implementing classes write `withSize(size:IntoSize):<Self>`. Haxe has no
 * `Self` return type, so the shortcuts `xsmall()`, `small()` and `large()`
 * are added to each implementing class by `SizableMacro.build()`, returning
 * the class itself, and `prepareForToolbar()` gets its default (return this).
 * `setSize` is the untyped entry point used by generic owners (groups that
 * size their children).
 */
@:autoBuild(glaze.kit.SizableMacro.build())
interface Sizable {

    /**
     * Sets the size, in place (Rust `with_size` on an untyped `Sizable`).
     */
    function setSize(size:Size):Void;

}
