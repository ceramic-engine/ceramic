// Ported from gpui-kit 0.8.1: crates/base/src/actions.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

import gpui.Action;

/**
 * Common actions shared by keyboard-driven GPUI controls (namespace `ui`).
 * Import this module (`import gpui.base.Actions;`) to use them.
 */
class Actions {}

/**
 * Confirm, with whether the confirmation uses the secondary action.
 */
@:action(namespace = ui, noJson)
class Confirm implements Action {

    /** Whether the confirmation uses the secondary action. */
    public final secondary:Bool;

}

@:action(namespace = ui) class Cancel implements Action {}

@:action(namespace = ui) class SelectUp implements Action {}

@:action(namespace = ui) class SelectDown implements Action {}

@:action(namespace = ui) class SelectLeft implements Action {}

@:action(namespace = ui) class SelectRight implements Action {}

@:action(namespace = ui) class SelectFirst implements Action {}

@:action(namespace = ui) class SelectLast implements Action {}

@:action(namespace = ui) class SelectPrevColumn implements Action {}

@:action(namespace = ui) class SelectNextColumn implements Action {}

@:action(namespace = ui) class SelectPageUp implements Action {}

@:action(namespace = ui) class SelectPageDown implements Action {}
