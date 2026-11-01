// Ported from gpui-kit 0.8.1: crates/component/src/highlighter/wasm_stub.rs (SyntaxHighlighter)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.highlighter;

import gpui.HighlightStyle;
import gpui.Range;
import gpui.base.input.InputEdit;
import gpui.base.input.StyledRange;
import ropey.Rope;
import gpui.component.highlighter.TextMateBackend.CaptureName;

/**
 * Syntax highlighter stub of gpui-kit's builds without tree-sitter. With a
 * highlighter (syntect there, TextMate here, see `Highlighter.enable`) it
 * names highlights for the presentations that resolve styles themselves,
 * such as a diff.
 */
class SyntaxHighlighter {

    final _language:String;

    public function new(language:String) {
        this._language = language;
    }

    public function highlight(_text:Rope):Array<StyledRange> {
        return [];
    }

    public function styles(range:Range, _theme:HighlightTheme):Array<StyledRange> {
        // If the matched styles is empty, return a default range.
        return [new StyledRange(range, new HighlightStyle())];
    }

    public function update(_edit:Null<InputEdit>, _text:Rope, ?_timeout:Float):Bool {
        // No-op without tree-sitter
        return true;
    }

    @:allow(gpui.component)
    function captureNames(text:Rope):Array<CaptureName> {
        if (Highlighter.enabled)
            return TextMateBackend.captureNames(_language, text.toString());
        return [];
    }

    public function editTree(_edit:Null<InputEdit>, _text:Rope):Void {
        // No-op without tree-sitter
    }

    /**
     * Always empty, like the stub of the original (it does not return the
     * language given to `new`).
     */
    public function language():String {
        return "";
    }

    public function text():Rope {
        return Rope.fromStr("");
    }

}
