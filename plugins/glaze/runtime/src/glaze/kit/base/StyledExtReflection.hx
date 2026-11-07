// Ported from gpui-kit 0.8.1: crates/base/src/styled.rs (`#[derive_inspector_reflection]` on
// `StyledExt`: `styled_ext_reflection_methods`)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.base;

/**
 * Runtime access to the `StyledExt` methods of the form `fn name(self) ->
 * Self` (Rust `gpui_base::styled_ext_reflection_methods`): `h_flex`,
 * `v_flex` and the `debug_*` borders. The table is `StyledExtReflection.json`.
 */
#if !macro
@:build(gpui.StyledReflectionMacro.build('StyledExtReflection.json', true))
#end
class StyledExtReflection {}
