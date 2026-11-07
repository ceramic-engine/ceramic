// Ported from gpui-pre 0.3.10: src/styled.rs (`#[derive_inspector_reflection]` on `Styled`:
// the `styled_reflection` module)
// Original code Copyright 2022-2025 Zed Industries, Inc., licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui;

/**
 * Runtime access to the `Styled` methods of the form `fn name(self) -> Self`
 * (Rust `gpui::styled_reflection`), used by gpui-kit's inspector: their
 * Rust names in declaration order, their documentation, and a way to apply
 * them to a `StyleRefinement`. The table is `StyledReflection.json`.
 */
#if !macro
@:build(gpui.StyledReflectionMacro.build('StyledReflection.json', false))
#end
class StyledReflection {}
