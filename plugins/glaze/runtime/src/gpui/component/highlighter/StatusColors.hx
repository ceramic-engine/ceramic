// Ported from gpui-kit 0.8.1: crates/component/src/highlighter/wasm_stub.rs (StatusColors)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.highlighter;

import gpui.App;
import gpui.Hsla;

/**
 * The status colors of a highlight theme (diagnostics).
 *
 * gpui-kit only has real status colors in its tree-sitter builds
 * (`registry.rs`). Without tree-sitter (no highlighter, or the `syntect`
 * one, the configuration the port follows) `StatusColors` is the stub of
 * `wasm_stub.rs`: it reads nothing from the theme and every color is
 * `Hsla::default()`, a transparent black. The port keeps that.
 */
class StatusColors {

    public function new() {}

    public function error(cx:App):Hsla {
        return new Hsla();
    }

    public function errorBackground(cx:App):Hsla {
        return new Hsla();
    }

    public function errorBorder(cx:App):Hsla {
        return new Hsla();
    }

    public function warning(cx:App):Hsla {
        return new Hsla();
    }

    public function warningBackground(cx:App):Hsla {
        return new Hsla();
    }

    public function warningBorder(cx:App):Hsla {
        return new Hsla();
    }

    public function info(cx:App):Hsla {
        return new Hsla();
    }

    public function infoBackground(cx:App):Hsla {
        return new Hsla();
    }

    public function infoBorder(cx:App):Hsla {
        return new Hsla();
    }

    public function success(cx:App):Hsla {
        return new Hsla();
    }

    public function successBackground(cx:App):Hsla {
        return new Hsla();
    }

    public function successBorder(cx:App):Hsla {
        return new Hsla();
    }

    public function hint(cx:App):Hsla {
        return new Hsla();
    }

    public function hintBackground(cx:App):Hsla {
        return new Hsla();
    }

    public function hintBorder(cx:App):Hsla {
        return new Hsla();
    }

    public function equals(other:Null<StatusColors>):Bool {
        return other != null;
    }

}
