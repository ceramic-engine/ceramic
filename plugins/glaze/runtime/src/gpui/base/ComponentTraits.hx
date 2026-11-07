// Ported from gpui-kit 0.8.1: crates/base/src/component_traits.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

/**
 * Module of the component traits: `Selectable`, `Disableable`,
 * `FocusableExt` and `Collapsible`.
 *
 * Rust's builder methods return `Self`, which Haxe interfaces cannot
 * express: implementing classes write the fluent builders (`selected(b)`,
 * `disabled(b)`...) returning their own type, and the interfaces declare the
 * state accessors plus an untyped setter for generic owners.
 */
class ComponentTraits {}

/**
 * An element or component that exposes controlled selected state.
 *
 * `selected` is the application's own meaning of selection. `open` is a
 * separate state a popover, menu or dropdown puts on its trigger for as long
 * as it is open; it falls back to `selected` by default (see
 * `SelectableDefaults`).
 */
interface Selectable {

    function setSelected(selected:Bool):Void;

    function isSelected():Bool;

    /**
     * Sets the open state a popover, menu or dropdown holds on its trigger
     * while it is open. Default: `setSelected(open)`.
     */
    function setOpen(open:Bool):Void;

    /**
     * Whether the trigger is currently marked open. Default: `isSelected()`.
     */
    function isOpen():Bool;

}

/**
 * An element or component that can be disabled.
 */
interface Disableable {

    function setDisabled(disabled:Bool):Void;

}

/**
 * A component that exposes whether its UI layer should draw a focus ring.
 * This trait carries state only.
 */
interface FocusableExt {

    function setFocusRing(enabled:Bool):Void;

    function isFocusRingEnabled():Bool;

}

/**
 * An element or component that exposes collapsed state.
 */
interface Collapsible {

    function setCollapsed(collapsed:Bool):Void;

    function isCollapsed():Bool;

}
