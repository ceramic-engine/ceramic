// Ported from gpui-kit 0.8.1: crates/base/src/input/base/kind.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

/**
 * What kind of input a state is (Rust trait `InputModeKind`, implemented by
 * the mode markers).
 *
 * The input states are one engine seen through a mode: `InputMode`
 * (`InputState`) and `TextareaMode` (`TextareaState`). Rust picks it at
 * compile time; the port keeps one non-generic `InputBaseState` holding its
 * `modeKind`. The set is closed (Rust seals the trait): `InputMode.instance`
 * and `TextareaMode.instance`.
 *
 * gpui-kit's third mode, the code editor (`EditorMode`, `EditorState`) and
 * the trait's hooks only it implements (highlighter, language features,
 * completion and code action menus, hover, inline completion) are not part
 * of Glaze: the code editor of Glaze is Cityscape (plugin `cityscape`).
 *
 * `LayoutMode` carries how the text is laid out at runtime; the kind
 * decides what the input is.
 */
interface InputModeKind {

    /**
     * Whether this kind of input spans more than one line (Rust
     * `const MULTI_LINE`).
     *
     * The kind decides this, not the layout: `LayoutMode` carries how many
     * rows to show and how to grow, which is a different question from
     * whether the input is a text field or a document.
     */
    function multiLine():Bool;

}
