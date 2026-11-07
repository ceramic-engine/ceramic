// Ported from gpui-kit 0.8.1: crates/base/src/input/base/kind.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * What a mode can offer its context menu (Rust `(bool, bool)`).
 */
class ContextMenuSupport {

    public static final NONE = new ContextMenuSupport(false, false);

    public final goToDefinition:Bool;

    public final codeActions:Bool;

    public inline function new(goToDefinition:Bool, codeActions:Bool) {
        this.goToDefinition = goToDefinition;
        this.codeActions = codeActions;
    }

}
