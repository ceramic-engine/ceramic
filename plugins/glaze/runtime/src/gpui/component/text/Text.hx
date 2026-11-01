// Ported from gpui-kit 0.8.1: crates/component/src/text/compat.rs (Text)
// Original code Copyright 2024-2026 Longbridge, licensed under Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic. See NOTICE.md.
package gpui.component.text;

import gpui.AnyElement;
import gpui.App;
import gpui.IntoElement;
import gpui.Window;

/**
 * Either a plain string or a rich `TextView`.
 */
@:using(gpui.component.text.Text.TextTools)
enum Text {
    String(value:std.String);
    TextView(view:gpui.component.text.TextView);
}

/**
 * Rust `From<SharedString>`, `From<String>`, `From<&str>` and
 * `From<TextView>` for `Text`.
 */
abstract IntoText(Text) from Text to Text {

    @:from static inline function fromString(value:std.String):IntoText {
        return Text.String(value);
    }

    @:from static inline function fromTextView(view:gpui.component.text.TextView):IntoText {
        return Text.TextView(view);
    }

}

class TextTools {

    /**
     * Sets the style for the `TextView`. Does nothing for a plain string.
     */
    public static function style(self:Text, style:TextViewStyle):Text {
        return switch self {
            case String(value): String(value);
            case TextView(view): TextView(view.withStyle(style));
        }
    }

    /**
     * The text of a string or of a text view (used to match a search query).
     */
    public static function getText(self:Text, cx:App):std.String {
        return switch self {
            case String(value): value;
            case TextView(view): gpui.base.text.Text.ofTextView(view.inner).getText(cx);
        }
    }

    /**
     * Rust `text.into_any_element()` (the `RenderOnce` of `Text`).
     */
    public static function intoAnyElement(self:Text):AnyElement {
        return switch self {
            case String(value): (value : IntoElement).intoAnyElement();
            case TextView(view): view.intoAnyElement();
        }
    }

    /**
     * Rust `impl RenderOnce for Text`.
     */
    public static function render(self:Text, window:Window, cx:App):AnyElement {
        return switch self {
            case String(value): (value : IntoElement).intoAnyElement();
            case TextView(view): view.intoAnyElement();
        }
    }

}
