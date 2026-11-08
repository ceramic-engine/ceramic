// Ported from gpui-kit 0.8.1: crates/base/src/text/mod.rs
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package glaze.kit.base.text;

import glaze.App;
import glaze.ElementId;
import glaze.IntoElement;
import glaze.RenderOnce;
import glaze.Window;

/** The two forms of `Text` (Rust enum `Text`). */
enum TextKind {
    String(text:std.String);
    TextView(view:glaze.kit.base.text.TextView);
}

/**
 * Plain text or a rich text view (Rust enum `Text`), and the module functions
 * of Rust's `text` module (`init`, `markdown`, `html`).
 *
 * Rust's `From` conversions are `Text.ofString` and `Text.ofTextView`.
 */
class Text implements RenderOnce {

    public final kind:TextKind;

    function new(kind:TextKind) {
        this.kind = kind;
    }

    /** Rust `text::init`. */
    public static function bindKeys(cx:App):Void {
        Inline.init(cx);
        TextViewState.init(cx);
    }

    /** Create a new markdown text view with code location as id. */
    public static function markdown(source:String, ?pos:haxe.PosInfos):glaze.kit.base.text.TextView {
        final id = ElementId.CodeLocation(pos.fileName, pos.lineNumber);
        return glaze.kit.base.text.TextView.markdown(id, source);
    }

    /** Create a new html text view with code location as id. */
    public static function html(source:String, ?pos:haxe.PosInfos):glaze.kit.base.text.TextView {
        final id = ElementId.CodeLocation(pos.fileName, pos.lineNumber);
        return glaze.kit.base.text.TextView.html(id, source);
    }

    /** Rust `impl From<SharedString / &str / String> for Text`. */
    public static function ofString(s:std.String):Text {
        return new Text(String(s));
    }

    /** Rust `impl From<TextView> for Text`. */
    public static function ofTextView(view:glaze.kit.base.text.TextView):Text {
        return new Text(TextView(view));
    }

    /**
     * Set the style for `TextView`.
     *
     * Do nothing if this is `String`.
     */
    public function style(style:TextViewStyle):Text {
        return switch kind {
            case String(_): this;
            case TextView(view): new Text(TextView(view.withStyle(style)));
        }
    }

    /** Get the text content. */
    public function getText(cx:App):std.String {
        return switch kind {
            case String(s): s;
            case TextView(view):
                final state = view.state;
                state != null ? state.read(cx).source() : '';
        }
    }

    public function render(_:Window, _:App):IntoElement {
        return switch kind {
            case String(s): s;
            case TextView(view): view;
        }
    }

}
