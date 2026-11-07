// Ported from gpui-kit 0.8.1: crates/base/src/input/editor/highlighting.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.input;

import glaze.AnyElement;
import glaze.Hsla;
import glaze.kit.base.theme.SemanticThemeTokens;

/**
 * Application-owned colors and highlight resolver consumed by editor painting.
 *
 * Without arguments, Rust's `InputEditorStyle::default()`: every color is
 * transparent (unset) and the resolver resolves nothing.
 */
class InputEditorStyle {

    public var foreground:Hsla;

    public var mutedForeground:Hsla;

    public var background:Hsla;

    public var border:Hsla;

    public var selection:Hsla;

    public var caret:Hsla;

    public var diagnostics:DiagnosticColors;

    public var highlightStyles:HighlightStyleResolver;

    public var editorInvisible:Null<Hsla>;

    public var editorActiveLine:Null<Hsla>;

    public var editorGutterBackground:Null<Hsla>;

    public var foldIconRenderer:Null<FoldIconRenderer>;

    public function new(?foreground:Hsla, ?mutedForeground:Hsla, ?background:Hsla, ?border:Hsla, ?selection:Hsla, ?caret:Hsla, ?diagnostics:DiagnosticColors, ?highlightStyles:HighlightStyleResolver, ?editorInvisible:Hsla, ?editorActiveLine:Hsla, ?editorGutterBackground:Hsla, ?foldIconRenderer:FoldIconRenderer) {
        this.foreground = foreground != null ? foreground : new Hsla();
        this.mutedForeground = mutedForeground != null ? mutedForeground : new Hsla();
        this.background = background != null ? background : new Hsla();
        this.border = border != null ? border : new Hsla();
        this.selection = selection != null ? selection : new Hsla();
        this.caret = caret != null ? caret : new Hsla();
        this.diagnostics = diagnostics != null ? diagnostics : new DiagnosticColors();
        this.highlightStyles = highlightStyles != null ? highlightStyles : new NoHighlightStyles();
        this.editorInvisible = editorInvisible;
        this.editorActiveLine = editorActiveLine;
        this.editorGutterBackground = editorGutterBackground;
        this.foldIconRenderer = foldIconRenderer;
    }

    public static inline function defaultValue():InputEditorStyle {
        return new InputEditorStyle();
    }

    /** Rust `Clone` (the resolver and the fold icon renderer are shared, like their `Rc`) */
    public function clone():InputEditorStyle {
        return new InputEditorStyle(foreground, mutedForeground, background, border, selection, caret, diagnostics.copy(), highlightStyles, editorInvisible, editorActiveLine, editorGutterBackground, foldIconRenderer);
    }

    /**
     * Fills in every colour that was left unset, from the active palette.
     *
     * `Hsla::default()` is fully transparent, and every colour on `Default` is
     * that, so an input nothing projected onto painted its glyphs, its caret
     * and its selection in nothing at all. Transparent is not a colour anyone
     * means for ink, which is what makes it usable as "unset" here.
     *
     * This is resolution, not assignment: whatever a consumer did project is
     * kept exactly. `crates/component` projects the whole style on every render and
     * never reaches this; a consumer that projects once at construction gets
     * the palette that is current now rather than the one that happened to be
     * installed when the state was built.
     */
    public function resolved(tokens:SemanticThemeTokens):InputEditorStyle {
        final colors = tokens.colors;
        inline function unset(value:Hsla):Bool {
            return value.a == 0.0;
        }
        inline function or(value:Hsla, fallback:Hsla):Hsla {
            return unset(value) ? fallback : value;
        }

        final foreground = or(this.foreground, colors.foreground);
        var selection = this.selection;
        if (unset(selection)) {
            // A selection must not hide the glyphs it selects.
            selection = new Hsla(colors.accent.h, colors.accent.s, colors.accent.l, 0.4);
        }

        final result = clone();
        result.foreground = foreground;
        result.mutedForeground = or(this.mutedForeground, colors.mutedForeground);
        result.background = or(this.background, colors.surface);
        result.border = or(this.border, colors.border);
        result.selection = selection;
        result.caret = or(this.caret, foreground);
        return result;
    }

}
